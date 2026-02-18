#!/usr/bin/env bash
# healthcheck.sh — OAuth2 Proxy-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_OAUTH2_PROXY_HOSTNAME is expected to be set by the pre-install hook.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_oauth2_proxy_hostname="${PARAM_OAUTH2_PROXY_HOSTNAME:?PARAM_OAUTH2_PROXY_HOSTNAME is required}"

check_oauth2_proxy_https() {
    log_info "[oauth2-proxy/healthcheck] Checking HTTPS at ${_oauth2_proxy_hostname}..."

    # Allow extra time for cert-manager to provision the certificate
    retry_with_timeout 180 10 _oauth2_proxy_responds

    log_info "[oauth2-proxy/healthcheck] OAuth2 Proxy is responding at https://${_oauth2_proxy_hostname}."
}

_oauth2_proxy_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 10 "https://${_oauth2_proxy_hostname}/ping" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302|403)$ ]]
}

check_oauth2_proxy_https
