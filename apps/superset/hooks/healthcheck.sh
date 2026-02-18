#!/usr/bin/env bash
# healthcheck.sh — Superset-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_SUPERSET_HOSTNAME is expected to be set by the pre-install hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_superset_hostname="${PARAM_SUPERSET_HOSTNAME:?PARAM_SUPERSET_HOSTNAME is required}"

check_superset_https() {
    log_info "[superset/healthcheck] Checking HTTPS at ${_superset_hostname}..."

    retry_with_timeout 300 15 _superset_responds

    log_info "[superset/healthcheck] Superset is responding at https://${_superset_hostname}."
}

_superset_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 15 --location "https://${_superset_hostname}/health" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

check_superset_https
