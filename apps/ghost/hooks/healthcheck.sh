#!/usr/bin/env bash
# healthcheck.sh — Ghost-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_GHOST_HOSTNAME is expected to be set by the pre-install hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_ghost_hostname="${PARAM_GHOST_HOSTNAME:?PARAM_GHOST_HOSTNAME is required}"

check_ghost_https() {
    log_info "[ghost/healthcheck] Checking HTTPS at ${_ghost_hostname}..."

    retry_with_timeout 300 15 _ghost_responds

    log_info "[ghost/healthcheck] Ghost is responding at https://${_ghost_hostname}."
}

_ghost_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 15 --location "https://${_ghost_hostname}/" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

check_ghost_https
