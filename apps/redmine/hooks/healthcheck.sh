#!/usr/bin/env bash
# healthcheck.sh — Redmine-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_REDMINE_HOSTNAME is expected to be set by the pre-install hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_redmine_hostname="${PARAM_REDMINE_HOSTNAME:?PARAM_REDMINE_HOSTNAME is required}"

check_redmine_https() {
    log_info "[redmine/healthcheck] Checking HTTPS at ${_redmine_hostname}..."

    retry_with_timeout 300 15 _redmine_responds

    log_info "[redmine/healthcheck] Redmine is responding at https://${_redmine_hostname}."
}

_redmine_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 15 --location "https://${_redmine_hostname}/" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

check_redmine_https
