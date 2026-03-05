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

# ssl_apply_gateway <app_name> <hostname> [tls_secret] [issuer_name]
ssl_apply_gateway() {
    local app_name="$1"
    local hostname="$2"
    local tls_secret="${3:-${app_name}-tls}"
    local issuer_name="${4:-letsencrypt}"
    local namespace="${HELM_NAMESPACE_PREFIX}${app_name}"

    # Ensure namespace exists
    kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -

    log_info "[ssl-hooks] Applying Gateway for ${app_name} (issuer: ${issuer_name})..."
    kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: app-gateway
  namespace: ${namespace}
  annotations:
    cert-manager.io/cluster-issuer: ${issuer_name}
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

    # CI guard: skip SSL infrastructure, set dummy hostname
    if [[ "${CI_SKIP_SSL:-false}" == "true" ]]; then
        log_info "[ssl-hooks] CI_SKIP_SSL=true — skipping Gateway/HTTPRoute."
        export "$hostname_var=localhost"
        export SSL_HOSTNAME="localhost"
        return 0
    fi

    local issuer_name
    issuer_name="$(_ssl_get_active_issuer)"

    ssl_setup_hostname "$hostname_var"
    ssl_apply_gateway "$app_name" "$SSL_HOSTNAME" "$tls_secret" "$issuer_name"
    ssl_apply_httproute "$app_name" "$SSL_HOSTNAME" "$service_name" "$service_port"

    log_info "[ssl-hooks] Gateway and HTTPRoute applied for ${app_name} (issuer: ${issuer_name})."
}

# ── Issuer Selection ─────────────────────────────────────────────────────────

# _ssl_get_active_issuer — Resolve initial issuer based on ACME_PROVIDER.
_ssl_get_active_issuer() {
    local provider="${ACME_PROVIDER:-$DEFAULT_ACME_PROVIDER}"
    case "$provider" in
        "$ACME_PROVIDER_ZEROSSL")
            echo "zerossl"
            ;;
        *)
            echo "letsencrypt"
            ;;
    esac
}

# ── Certificate Fallback ─────────────────────────────────────────────────────

# _ssl_check_cert_ready <tls_secret_name> <namespace>
# Returns 0 if the Certificate resource is Ready=True.
_ssl_check_cert_ready() {
    local tls_secret="$1"
    local namespace="$2"

    local ready
    ready="$(kubectl get certificate "$tls_secret" -n "$namespace" \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)"
    [[ "$ready" == "True" ]]
}

# _ssl_detect_acme_failure <tls_secret_name> <namespace>
# Returns 0 if the Certificate status indicates a rate limit or ACME error
# that warrants switching to the fallback issuer.
_ssl_detect_acme_failure() {
    local tls_secret="$1"
    local namespace="$2"

    local message
    message="$(kubectl get certificate "$tls_secret" -n "$namespace" \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null)"

    # Also check Issuing condition for order errors
    if [[ -z "$message" || "$message" != *"failed"* ]]; then
        local issuing_msg
        issuing_msg="$(kubectl get certificate "$tls_secret" -n "$namespace" \
            -o jsonpath='{.status.conditions[?(@.type=="Issuing")].message}' 2>/dev/null)"
        [[ -n "$issuing_msg" ]] && message="${message} ${issuing_msg}"
    fi

    [[ -z "$message" ]] && return 1

    local lower_msg
    lower_msg="$(echo "$message" | tr '[:upper:]' '[:lower:]')"

    # Rate limit patterns
    [[ "$lower_msg" == *"too many"* ]] || \
    [[ "$lower_msg" == *"ratelimited"* ]] || \
    [[ "$lower_msg" == *"rate limit"* ]] || \
    # ACME order failure patterns (e.g. "order is in errored state")
    [[ "$lower_msg" == *"order is in \"errored\""* ]] || \
    [[ "$lower_msg" == *"acme:error:malformed"* ]] || \
    [[ "$lower_msg" == *"acme:error:unauthorized"* ]] || \
    [[ "$lower_msg" == *"failed to fetch authorization"* ]]
}

# Backward-compatible alias
_ssl_detect_rate_limit() { _ssl_detect_acme_failure "$@"; }

# _ssl_switch_issuer <app_name> <tls_secret_name> <new_issuer>
# Deletes failed Certificate+Secret and re-annotates Gateway with the new issuer.
_ssl_switch_issuer() {
    local app_name="$1"
    local tls_secret="$2"
    local new_issuer="$3"
    local namespace="${HELM_NAMESPACE_PREFIX}${app_name}"

    log_info "[ssl-hooks] Switching issuer to '${new_issuer}'..."

    # Delete the failed Certificate and its Secret so cert-manager re-creates them
    kubectl delete certificate "$tls_secret" -n "$namespace" --ignore-not-found=true
    kubectl delete secret "$tls_secret" -n "$namespace" --ignore-not-found=true

    # Re-annotate the Gateway to use the new issuer
    kubectl annotate gateway app-gateway -n "$namespace" \
        cert-manager.io/cluster-issuer="$new_issuer" --overwrite

    log_info "[ssl-hooks] Gateway re-annotated with issuer '${new_issuer}'."
}

# ssl_wait_for_cert_with_fallback <app_name> [tls_secret]
# Polls Certificate readiness. If rate-limited, switches to ZeroSSL and retries.
ssl_wait_for_cert_with_fallback() {
    local app_name="$1"
    local tls_secret="${2:-${app_name}-tls}"
    local namespace="${HELM_NAMESPACE_PREFIX}${app_name}"
    local provider="${ACME_PROVIDER:-$DEFAULT_ACME_PROVIDER}"
    local timeout="$TIMEOUT_CERT_READY"
    local interval="$CERT_CHECK_INTERVAL"

    # Skip in CI
    if [[ "${CI_SKIP_SSL:-false}" == "true" ]]; then
        log_info "[ssl-hooks] CI_SKIP_SSL=true — skipping cert verification."
        return 0
    fi

    log_info "[ssl-hooks] Waiting for certificate '${tls_secret}' (timeout: ${timeout}s)..."

    local deadline
    deadline=$((SECONDS + timeout))

    # Phase 1: Wait for primary issuer
    while [[ $SECONDS -lt $deadline ]]; do
        if _ssl_check_cert_ready "$tls_secret" "$namespace"; then
            log_info "[ssl-hooks] Certificate '${tls_secret}' is ready."
            return 0
        fi

        # Check for ACME failure (rate limit, order error) — fallback in auto mode
        if [[ "$provider" == "$ACME_PROVIDER_AUTO" ]]; then
            if _ssl_detect_acme_failure "$tls_secret" "$namespace"; then
                # Verify ZeroSSL issuer exists before trying fallback
                if kubectl get clusterissuer zerossl &>/dev/null; then
                    log_warn "[ssl-hooks] ACME failure detected on primary issuer."
                    _ssl_switch_issuer "$app_name" "$tls_secret" "zerossl"
                    break
                else
                    log_warn "[ssl-hooks] Rate limit detected but ZeroSSL issuer not available."
                fi
            fi
        fi

        sleep "$interval"
    done

    # Phase 2: Wait for fallback issuer (if we switched)
    while [[ $SECONDS -lt $deadline ]]; do
        if _ssl_check_cert_ready "$tls_secret" "$namespace"; then
            log_info "[ssl-hooks] Certificate '${tls_secret}' is ready (via ZeroSSL fallback)."
            return 0
        fi
        sleep "$interval"
    done

    log_warn "[ssl-hooks] Certificate '${tls_secret}' not ready after ${timeout}s."
    return 1
}

readonly _SSL_HOOKS_LOADED=1
