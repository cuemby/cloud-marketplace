#!/usr/bin/env bash
# healthcheck.sh — Jenkins-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_JENKINS_HOSTNAME is expected to be set by the pre-install hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_jenkins_hostname="${PARAM_JENKINS_HOSTNAME:?PARAM_JENKINS_HOSTNAME is required}"

check_jenkins_https() {
    log_info "[jenkins/healthcheck] Checking HTTPS at ${_jenkins_hostname}..."

    # Extra generous timeout — JVM boot is slow
    retry_with_timeout 420 15 _jenkins_responds

    log_info "[jenkins/healthcheck] Jenkins is responding at https://${_jenkins_hostname}."
}

_jenkins_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 15 --location "https://${_jenkins_hostname}/login" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

check_jenkins_https
