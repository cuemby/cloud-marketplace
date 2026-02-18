#!/usr/bin/env bash
# healthcheck.sh — SonarQube-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_SONARQUBE_HOSTNAME is expected to be set by the pre-install hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_sonarqube_hostname="${PARAM_SONARQUBE_HOSTNAME:?PARAM_SONARQUBE_HOSTNAME is required}"

check_sonarqube_https() {
    log_info "[sonarqube/healthcheck] Checking HTTPS at ${_sonarqube_hostname}..."

    # Extra generous timeout — JVM boot is slow
    retry_with_timeout 420 15 _sonarqube_responds

    log_info "[sonarqube/healthcheck] SonarQube is responding at https://${_sonarqube_hostname}."
}

_sonarqube_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 15 --location "https://${_sonarqube_hostname}/" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

check_sonarqube_https
