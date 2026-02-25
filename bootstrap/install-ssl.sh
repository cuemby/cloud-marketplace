#!/usr/bin/env bash
# install-ssl.sh — Install cert-manager and create ACME ClusterIssuers.
# Supports Let's Encrypt (default), ZeroSSL (fallback), or both (auto mode).
# Called from entrypoint.sh when an app declares ssl.enabled: true.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/constants.sh
source "${SCRIPT_DIR}/lib/constants.sh"
# shellcheck source=lib/logging.sh
source "${SCRIPT_DIR}/lib/logging.sh"
# shellcheck source=lib/retry.sh
source "${SCRIPT_DIR}/lib/retry.sh"

install_ssl() {
    log_section "Installing SSL infrastructure (cert-manager)"

    _install_cert_manager
    _wait_for_cert_manager

    local provider="${ACME_PROVIDER:-$DEFAULT_ACME_PROVIDER}"
    log_info "ACME provider mode: ${provider}"

    case "$provider" in
        "$ACME_PROVIDER_AUTO")
            _create_letsencrypt_issuer
            # ZeroSSL: best-effort in auto mode (failure = warning, fallback disabled)
            if [[ "${ACME_USE_STAGING:-false}" == "true" ]]; then
                log_info "Staging mode — skipping ZeroSSL issuer (not needed for testing)."
            else
                _create_zerossl_issuer || \
                    log_warn "ZeroSSL issuer creation failed; fallback will not be available."
            fi
            ;;
        "$ACME_PROVIDER_LETSENCRYPT")
            _create_letsencrypt_issuer
            ;;
        "$ACME_PROVIDER_ZEROSSL")
            _create_zerossl_issuer
            ;;
        *)
            log_fatal "Unknown ACME_PROVIDER '${provider}'. Valid: auto, letsencrypt, zerossl."
            ;;
    esac

    log_info "SSL infrastructure ready."
}

_install_cert_manager() {
    # Skip if already installed
    if helm status cert-manager -n "$CERT_MANAGER_NAMESPACE" &>/dev/null; then
        log_info "cert-manager already installed, skipping."
        return 0
    fi

    log_info "Installing cert-manager ${CERT_MANAGER_VERSION}..."

    helm repo add jetstack https://charts.jetstack.io --force-update
    helm repo update jetstack

    kubectl create namespace "$CERT_MANAGER_NAMESPACE" \
        --dry-run=client -o yaml | kubectl apply -f -

    helm install cert-manager jetstack/cert-manager \
        --namespace "$CERT_MANAGER_NAMESPACE" \
        --version "$CERT_MANAGER_VERSION" \
        --set crds.enabled=true \
        --set "extraArgs={--enable-gateway-api}" \
        --wait \
        --timeout 300s

    log_info "cert-manager installed."
}

_wait_for_cert_manager() {
    log_info "Waiting for cert-manager webhook to be ready..."
    retry_with_timeout "$TIMEOUT_CERT_MANAGER" "$RETRY_INTERVAL" \
        _cert_manager_webhook_ready
    log_info "cert-manager webhook is ready."
}

_cert_manager_webhook_ready() {
    local phase
    phase="$(kubectl get pods -n "$CERT_MANAGER_NAMESPACE" \
        -l app.kubernetes.io/component=webhook \
        -o jsonpath='{.items[0].status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

_create_letsencrypt_issuer() {
    local acme_server="$DEFAULT_ACME_SERVER"
    if [[ "${ACME_USE_STAGING:-false}" == "true" ]]; then
        acme_server="$ACME_SERVER_STAGING"
        log_warn "Using Let's Encrypt STAGING server (certs will not be trusted)."
    fi

    local acme_email="${ACME_EMAIL:-me@cuemby.com}"
    if [[ "$acme_email" == *"@example.com" ]]; then
        log_fatal "ACME_EMAIL must not use example.com. Set ACME_EMAIL or PARAM_\${APP_NAME^^}_ACME_EMAIL in your cloud-init."
    fi

    local app_namespace="${HELM_NAMESPACE_PREFIX}${APP_NAME}"

    log_info "Creating ClusterIssuer 'letsencrypt' (server: ${acme_server})..."

    kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    server: ${acme_server}
    email: ${acme_email}
    privateKeySecretRef:
      name: letsencrypt-account-key
    solvers:
      - http01:
          gatewayHTTPRoute:
            parentRefs:
              - name: app-gateway
                namespace: ${app_namespace}
                kind: Gateway
EOF

    log_info "ClusterIssuer 'letsencrypt' created."
}

# _fetch_zerossl_eab — Obtain EAB credentials from ZeroSSL API.
# Uses a random email per VM (no user config required).
# Outputs: sets ZEROSSL_EAB_KID and ZEROSSL_EAB_HMAC_KEY.
_fetch_zerossl_eab() {
    local zerossl_email
    zerossl_email="$(head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n')@cuemby.com"
    log_info "Fetching ZeroSSL EAB credentials (email: ${zerossl_email})..."

    local response
    response="$(curl -sf --max-time 30 -X POST "$ZEROSSL_EAB_API" \
        -d "email=${zerossl_email}" 2>/dev/null)" || {
        log_error "Failed to reach ZeroSSL EAB API."
        return 1
    }

    local success
    success="$(echo "$response" | jq -r '.success // false')"
    if [[ "$success" != "true" ]]; then
        log_error "ZeroSSL EAB API returned failure: ${response}"
        return 1
    fi

    ZEROSSL_EAB_KID="$(echo "$response" | jq -r '.eab_kid')"
    ZEROSSL_EAB_HMAC_KEY="$(echo "$response" | jq -r '.eab_hmac_key')"

    if [[ -z "$ZEROSSL_EAB_KID" || -z "$ZEROSSL_EAB_HMAC_KEY" ]]; then
        log_error "ZeroSSL EAB response missing kid or hmac_key."
        return 1
    fi

    log_info "ZeroSSL EAB credentials obtained (kid: ${ZEROSSL_EAB_KID:0:8}...)."
}

_create_zerossl_issuer() {
    _fetch_zerossl_eab || return 1

    local acme_email="${ACME_EMAIL:-me@cuemby.com}"
    local app_namespace="${HELM_NAMESPACE_PREFIX}${APP_NAME}"

    log_info "Creating ZeroSSL EAB Secret and ClusterIssuer..."

    # Create/update the EAB secret for ZeroSSL
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: zerossl-eab
  namespace: ${CERT_MANAGER_NAMESPACE}
type: Opaque
stringData:
  kid: "${ZEROSSL_EAB_KID}"
  hmacKey: "${ZEROSSL_EAB_HMAC_KEY}"
EOF

    kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: zerossl
spec:
  acme:
    server: ${ZEROSSL_ACME_SERVER}
    email: ${acme_email}
    privateKeySecretRef:
      name: zerossl-account-key
    externalAccountBinding:
      keyID: ${ZEROSSL_EAB_KID}
      keySecretRef:
        name: zerossl-eab
        key: hmacKey
      keyAlgorithm: HS256
    solvers:
      - http01:
          gatewayHTTPRoute:
            parentRefs:
              - name: app-gateway
                namespace: ${app_namespace}
                kind: Gateway
EOF

    log_info "ClusterIssuer 'zerossl' created."
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_ssl
fi
