#!/usr/bin/env bash
# ssl-hooks.sh — Reusable SSL/Gateway API functions for app pre-install hooks.
# Source this file from any SSL-enabled app's pre-install.sh.
#
# Required env vars:
#   APP_NAME — application name (e.g., "wordpress", "grafana")
#   HELM_NAMESPACE_PREFIX — namespace prefix (from constants.sh)
#
# Exported after calling ssl_setup_hostname:
#   SSL_HOSTNAME — the computed or provided hostname

# Source guard
[[ -n "${_SSL_HOOKS_LOADED:-}" ]] && return 0

_SSL_HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=logging.sh
source "${_SSL_HOOKS_DIR}/logging.sh"
# shellcheck source=constants.sh
source "${_SSL_HOOKS_DIR}/constants.sh"

# ── IP Detection ─────────────────────────────────────────────────────────────

ssl_detect_public_ip() {
    local ip=""
    local services=(
        "https://ifconfig.me"
        "https://ipinfo.io/ip"
        "https://api.ipify.org"
    )

    for svc in "${services[@]}"; do
        ip="$(curl -sf --max-time 10 "$svc" 2>/dev/null || true)"
        if _ssl_valid_ipv4 "$ip"; then
            echo "$ip"
            return 0
        fi
    done

    # Last resort: first non-loopback IP from hostname -I
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    if _ssl_valid_ipv4 "$ip"; then
        log_warn "[ssl-hooks] Using private IP ${ip} — cert issuance may fail."
        echo "$ip"
        return 0
    fi

    log_error "[ssl-hooks] Could not detect any IP address."
    return 1
}

_ssl_valid_ipv4() {
    local ip="$1"
    [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

ssl_ip_to_sslip_domain() {
    local ip="$1"
    echo "${ip//./-}.sslip.io"
}

# ── Hostname Setup ───────────────────────────────────────────────────────────

# ssl_setup_hostname <hostname_var_name>
# If the variable named by hostname_var_name is set, use it.
# Otherwise detect IP → sslip.io and export it back.
ssl_setup_hostname() {
    local var_name="$1"
    local current_value="${!var_name:-}"

    if [[ -n "$current_value" ]]; then
        log_info "[ssl-hooks] Using provided hostname: ${current_value}"
        export SSL_HOSTNAME="$current_value"
    else
        log_info "[ssl-hooks] Detecting public IP for sslip.io hostname..."
        local public_ip
        public_ip="$(ssl_detect_public_ip)"
        SSL_HOSTNAME="$(ssl_ip_to_sslip_domain "$public_ip")"
        export SSL_HOSTNAME
        export "$var_name=$SSL_HOSTNAME"
        log_info "[ssl-hooks] Hostname: ${SSL_HOSTNAME}"
    fi
}

# ── Gateway Resource ─────────────────────────────────────────────────────────

# ssl_apply_gateway <app_name> <hostname> <tls_secret_name>
ssl_apply_gateway() {
    local app_name="$1"
    local hostname="$2"
    local tls_secret="${3:-${app_name}-tls}"
    local namespace="${HELM_NAMESPACE_PREFIX}${app_name}"

    # Ensure namespace exists
    kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -

    log_info "[ssl-hooks] Applying Gateway for ${app_name}..."
    kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: app-gateway
  namespace: ${namespace}
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  gatewayClassName: traefik
  listeners:
    - name: web
      protocol: HTTP
      port: 8000
      hostname: "${hostname}"
      allowedRoutes:
        namespaces:
          from: Same
    - name: websecure
      protocol: HTTPS
      port: 8443
      hostname: "${hostname}"
      tls:
        mode: Terminate
        certificateRefs:
          - name: ${tls_secret}
            kind: Secret
      allowedRoutes:
        namespaces:
          from: Same
EOF
}

# ── HTTPRoute Resources ──────────────────────────────────────────────────────

# ssl_apply_httproute <app_name> <hostname> <service_name> <service_port>
ssl_apply_httproute() {
    local app_name="$1"
    local hostname="$2"
    local service_name="$3"
    local service_port="${4:-80}"
    local namespace="${HELM_NAMESPACE_PREFIX}${app_name}"

    log_info "[ssl-hooks] Applying HTTPRoute for ${app_name}..."
    kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: ${app_name}
  namespace: ${namespace}
spec:
  parentRefs:
    - name: app-gateway
      sectionName: websecure
  hostnames:
    - "${hostname}"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: ${service_name}
          port: ${service_port}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: ${app_name}-redirect
  namespace: ${namespace}
spec:
  parentRefs:
    - name: app-gateway
      sectionName: web
  hostnames:
    - "${hostname}"
  rules:
    - filters:
        - type: RequestRedirect
          requestRedirect:
            scheme: https
            statusCode: 301
EOF
}

# ── Convenience: Full SSL Setup ──────────────────────────────────────────────

# ssl_full_setup <app_name> <hostname_var_name> <service_name> <service_port> [tls_secret]
# One-call setup: hostname detection + Gateway + HTTPRoutes
ssl_full_setup() {
    local app_name="$1"
    local hostname_var="$2"
    local service_name="$3"
    local service_port="${4:-80}"
    local tls_secret="${5:-${app_name}-tls}"

    ssl_setup_hostname "$hostname_var"
    ssl_apply_gateway "$app_name" "$SSL_HOSTNAME" "$tls_secret"
    ssl_apply_httproute "$app_name" "$SSL_HOSTNAME" "$service_name" "$service_port"

    log_info "[ssl-hooks] Gateway and HTTPRoute applied for ${app_name}."
}

readonly _SSL_HOOKS_LOADED=1
