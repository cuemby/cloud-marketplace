#!/usr/bin/env bash
# healthcheck.sh — Concourse-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_CONCOURSE_HOSTNAME is expected to be set by the pre-install hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_concourse_hostname="${PARAM_CONCOURSE_HOSTNAME:?PARAM_CONCOURSE_HOSTNAME is required}"

check_concourse_https() {
    log_info "[concourse/healthcheck] Checking HTTPS at ${_concourse_hostname}..."

    retry_with_timeout 300 15 _concourse_responds

    log_info "[concourse/healthcheck] Concourse is responding at https://${_concourse_hostname}."
}

_concourse_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 15 --location "https://${_concourse_hostname}/" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

check_concourse_https
