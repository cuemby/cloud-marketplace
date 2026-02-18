#!/usr/bin/env bash
# healthcheck.sh — Odoo-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_ODOO_HOSTNAME is expected to be set by the pre-install hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_odoo_hostname="${PARAM_ODOO_HOSTNAME:?PARAM_ODOO_HOSTNAME is required}"

check_odoo_https() {
    log_info "[odoo/healthcheck] Checking HTTPS at ${_odoo_hostname}..."

    retry_with_timeout 300 15 _odoo_responds

    log_info "[odoo/healthcheck] Odoo is responding at https://${_odoo_hostname}."
}

_odoo_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 15 --location "https://${_odoo_hostname}/" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302|303)$ ]]
}

check_odoo_https
