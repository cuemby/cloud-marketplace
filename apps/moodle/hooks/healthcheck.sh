#!/usr/bin/env bash
# healthcheck.sh — Moodle-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_MOODLE_HOSTNAME is expected to be set by the pre-install hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_moodle_hostname="${PARAM_MOODLE_HOSTNAME:?PARAM_MOODLE_HOSTNAME is required}"

check_moodle_https() {
    log_info "[moodle/healthcheck] Checking HTTPS at ${_moodle_hostname}..."

    retry_with_timeout 300 15 _moodle_responds

    log_info "[moodle/healthcheck] Moodle is responding at https://${_moodle_hostname}."
}

_moodle_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 15 --location "https://${_moodle_hostname}/" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302|303)$ ]]
}

check_moodle_https
