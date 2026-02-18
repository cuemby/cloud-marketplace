#!/usr/bin/env bash
# healthcheck.sh — Matomo-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_MATOMO_HOSTNAME is expected to be set by the pre-install hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_matomo_hostname="${PARAM_MATOMO_HOSTNAME:?PARAM_MATOMO_HOSTNAME is required}"

check_matomo_https() {
    log_info "[matomo/healthcheck] Checking HTTPS at ${_matomo_hostname}..."

    retry_with_timeout 300 15 _matomo_responds

    log_info "[matomo/healthcheck] Matomo is responding at https://${_matomo_hostname}."
}

_matomo_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 15 --location "https://${_matomo_hostname}/" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

check_matomo_https
