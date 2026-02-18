#!/usr/bin/env bash
# healthcheck.sh — NGINX-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_NGINX_HOSTNAME is expected to be set by the pre-install hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_nginx_hostname="${PARAM_NGINX_HOSTNAME:?PARAM_NGINX_HOSTNAME is required}"

check_nginx_https() {
    log_info "[nginx/healthcheck] Checking HTTPS at ${_nginx_hostname}..."

    # NGINX starts fast — 180s timeout is sufficient
    retry_with_timeout 180 10 _nginx_responds

    log_info "[nginx/healthcheck] NGINX is responding at https://${_nginx_hostname}."
}

_nginx_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 10 --location "https://${_nginx_hostname}/" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

check_nginx_https
