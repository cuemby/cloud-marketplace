#!/usr/bin/env bash
# install-ssl.sh — Install cert-manager and create a Let's Encrypt ClusterIssuer.
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
    _create_cluster_issuer

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

_create_cluster_issuer() {
    local acme_server="$DEFAULT_ACME_SERVER"
    if [[ "${ACME_USE_STAGING:-false}" == "true" ]]; then
        acme_server="$ACME_SERVER_STAGING"
        log_warn "Using Let's Encrypt STAGING server (certs will not be trusted)."
    fi

    local acme_email="${ACME_EMAIL:-${PARAM_WORDPRESS_EMAIL:-admin@example.com}}"

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
                namespace: ${HELM_NAMESPACE_PREFIX}wordpress
                kind: Gateway
EOF

    log_info "ClusterIssuer 'letsencrypt' created."
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_ssl
fi
