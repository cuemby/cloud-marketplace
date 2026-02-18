#!/usr/bin/env bash
# healthcheck.sh — Grafana-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_GRAFANA_HOSTNAME is expected to be set by the pre-install hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_grafana_hostname="${PARAM_GRAFANA_HOSTNAME:?PARAM_GRAFANA_HOSTNAME is required}"

check_grafana_https() {
    log_info "[grafana/healthcheck] Checking HTTPS at ${_grafana_hostname}..."

    retry_with_timeout 300 15 _grafana_responds

    log_info "[grafana/healthcheck] Grafana is responding at https://${_grafana_hostname}."
}

_grafana_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 15 --location "https://${_grafana_hostname}/api/health" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

check_grafana_https
