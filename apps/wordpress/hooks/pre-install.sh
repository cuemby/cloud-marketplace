#!/usr/bin/env bash
# pre-install.sh — WordPress pre-install hook.
# Detects the VM's public IP, computes a sslip.io hostname, exports
# PARAM_WORDPRESS_HOSTNAME, and applies Gateway + HTTPRoute resources.
#
# This script is SOURCED (not subshelled) so exported vars propagate
# to deploy-app.sh's build_set_args and post-install/healthcheck hooks.

# Guard: only run setup once (idempotent when sourced multiple times)
[[ -n "${_WP_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"

_detect_public_ip() {
    local ip=""
    local services=(
        "https://ifconfig.me"
        "https://ipinfo.io/ip"
        "https://api.ipify.org"
    )

    for svc in "${services[@]}"; do
        ip="$(curl -sf --max-time 10 "$svc" 2>/dev/null || true)"
        if _valid_ipv4 "$ip"; then
            echo "$ip"
            return 0
        fi
    done

    # Last resort: first non-loopback IP from hostname -I
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    if _valid_ipv4 "$ip"; then
        log_warn "[wordpress/pre-install] Using private IP ${ip} — cert issuance may fail."
        echo "$ip"
        return 0
    fi

    log_error "[wordpress/pre-install] Could not detect any IP address."
    return 1
}

_valid_ipv4() {
    local ip="$1"
    [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

_ip_to_sslip_domain() {
    local ip="$1"
    echo "${ip//./-}.sslip.io"
}

# ── Determine hostname ─────────────────────────────────────────────────────

if [[ -n "${PARAM_WORDPRESS_HOSTNAME:-}" ]]; then
    log_info "[wordpress/pre-install] Using provided hostname: ${PARAM_WORDPRESS_HOSTNAME}"
else
    log_info "[wordpress/pre-install] Detecting public IP for sslip.io hostname..."
    public_ip="$(_detect_public_ip)"
    export PARAM_WORDPRESS_HOSTNAME
    PARAM_WORDPRESS_HOSTNAME="$(_ip_to_sslip_domain "$public_ip")"
    log_info "[wordpress/pre-install] Hostname: ${PARAM_WORDPRESS_HOSTNAME}"
fi

readonly _WP_NAMESPACE="${HELM_NAMESPACE_PREFIX}wordpress"

# Ensure namespace exists before applying resources
kubectl create namespace "$_WP_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# ── Apply Gateway ──────────────────────────────────────────────────────────

log_info "[wordpress/pre-install] Applying Gateway resource..."
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: app-gateway
  namespace: ${_WP_NAMESPACE}
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  gatewayClassName: traefik
  listeners:
    - name: web
      protocol: HTTP
      port: 80
      hostname: "${PARAM_WORDPRESS_HOSTNAME}"
      allowedRoutes:
        namespaces:
          from: Same
    - name: websecure
      protocol: HTTPS
      port: 443
      hostname: "${PARAM_WORDPRESS_HOSTNAME}"
      tls:
        mode: Terminate
        certificateRefs:
          - name: wordpress-tls
            kind: Secret
      allowedRoutes:
        namespaces:
          from: Same
EOF

# ── Apply HTTPRoute ────────────────────────────────────────────────────────

log_info "[wordpress/pre-install] Applying HTTPRoute resource..."
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: wordpress
  namespace: ${_WP_NAMESPACE}
spec:
  parentRefs:
    - name: app-gateway
      sectionName: websecure
  hostnames:
    - "${PARAM_WORDPRESS_HOSTNAME}"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: wordpress
          port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: wordpress-redirect
  namespace: ${_WP_NAMESPACE}
spec:
  parentRefs:
    - name: app-gateway
      sectionName: web
  hostnames:
    - "${PARAM_WORDPRESS_HOSTNAME}"
  rules:
    - filters:
        - type: RequestRedirect
          requestRedirect:
            scheme: https
            statusCode: 301
EOF

log_info "[wordpress/pre-install] Gateway and HTTPRoute applied."

export _WP_PRE_INSTALL_DONE=1
