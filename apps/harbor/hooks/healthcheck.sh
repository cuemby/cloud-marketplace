#!/usr/bin/env bash
# healthcheck.sh — Harbor-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_HARBOR_HOSTNAME is expected to be set by the pre-install hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_harbor_hostname="${PARAM_HARBOR_HOSTNAME:?PARAM_HARBOR_HOSTNAME is required}"

check_harbor_https() {
    log_info "[harbor/healthcheck] Checking HTTPS at ${_harbor_hostname}..."

    retry_with_timeout 300 15 _harbor_responds

    log_info "[harbor/healthcheck] Harbor is responding at https://${_harbor_hostname}."
}

_harbor_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 15 --location "https://${_harbor_hostname}/api/v2.0/health" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

check_harbor_https
