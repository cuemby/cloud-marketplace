#!/usr/bin/env bash
# healthcheck.sh — Appsmith-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_APPSMITH_HOSTNAME is expected to be set by the pre-install hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_appsmith_hostname="${PARAM_APPSMITH_HOSTNAME:?PARAM_APPSMITH_HOSTNAME is required}"

check_appsmith_https() {
    log_info "[appsmith/healthcheck] Checking HTTPS at ${_appsmith_hostname}..."

    retry_with_timeout 300 15 _appsmith_responds

    log_info "[appsmith/healthcheck] Appsmith is responding at https://${_appsmith_hostname}."
}

_appsmith_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 15 --location "https://${_appsmith_hostname}/" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

check_appsmith_https
