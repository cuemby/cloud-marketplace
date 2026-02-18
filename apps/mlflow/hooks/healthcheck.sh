#!/usr/bin/env bash
# healthcheck.sh — MLflow-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_MLFLOW_HOSTNAME is expected to be set by the pre-install hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_mlflow_hostname="${PARAM_MLFLOW_HOSTNAME:?PARAM_MLFLOW_HOSTNAME is required}"

check_mlflow_https() {
    log_info "[mlflow/healthcheck] Checking HTTPS at ${_mlflow_hostname}..."

    # Allow extra time for cert-manager to provision the certificate
    retry_with_timeout 300 15 _mlflow_responds

    log_info "[mlflow/healthcheck] MLflow is responding at https://${_mlflow_hostname}."
}

_mlflow_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 15 --location "https://${_mlflow_hostname}/" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

check_mlflow_https
