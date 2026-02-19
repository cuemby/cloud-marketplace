#!/usr/bin/env bash
# post-install.sh — MLflow post-install hook.
# Waits for the MLflow pod to be ready and logs access information.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}mlflow"

log_info "[mlflow/post-install] Waiting for MLflow to be ready..."

# --- Wait for MLflow pod to be ready ---
_get_mlflow_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=mlflow,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_mlflow_pod_ready() {
    local pod
    pod="$(_get_mlflow_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _mlflow_pod_ready

mlflow_pod="$(_get_mlflow_pod)"
log_info "[mlflow/post-install] MLflow pod ready: ${mlflow_pod}"

# --- Log access info ---
local_port="${PARAM_MLFLOW_NODEPORT:-30500}"
log_info "[mlflow/post-install] MLflow tracking UI: http://<VM-IP>:${local_port}"
log_info "[mlflow/post-install] No authentication required by default."
