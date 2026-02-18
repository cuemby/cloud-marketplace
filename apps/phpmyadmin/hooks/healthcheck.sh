#!/usr/bin/env bash
# healthcheck.sh — phpMyAdmin-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_PHPMYADMIN_HOSTNAME is expected to be set by the pre-install hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_pma_hostname="${PARAM_PHPMYADMIN_HOSTNAME:?PARAM_PHPMYADMIN_HOSTNAME is required}"

check_phpmyadmin_https() {
    log_info "[phpmyadmin/healthcheck] Checking HTTPS at ${_pma_hostname}..."

    retry_with_timeout 300 15 _pma_responds

    log_info "[phpmyadmin/healthcheck] phpMyAdmin is responding at https://${_pma_hostname}."
}

_pma_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 15 --location "https://${_pma_hostname}/" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

check_phpmyadmin_https
