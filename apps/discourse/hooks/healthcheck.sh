#!/usr/bin/env bash
# healthcheck.sh — Discourse-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_DISCOURSE_HOSTNAME is expected to be set by the pre-install hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_discourse_hostname="${PARAM_DISCOURSE_HOSTNAME:?PARAM_DISCOURSE_HOSTNAME is required}"

check_discourse_https() {
    log_info "[discourse/healthcheck] Checking HTTPS at ${_discourse_hostname}..."

    retry_with_timeout 300 15 _discourse_responds

    log_info "[discourse/healthcheck] Discourse is responding at https://${_discourse_hostname}."
}

_discourse_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 15 --location "https://${_discourse_hostname}/" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

check_discourse_https
