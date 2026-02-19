#!/usr/bin/env bash
# healthcheck.sh — MLflow-specific health checks.
# Called by the generic healthcheck after pod/service checks pass.
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

# --- Check 1: PostgreSQL accepts connections ---
_pg_is_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=mlflow,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        pg_isready -U mlflow 2>/dev/null
}

log_info "[mlflow/healthcheck] Checking PostgreSQL connectivity..."
retry_with_timeout 120 10 _pg_is_ready
log_info "[mlflow/healthcheck] PostgreSQL is accepting connections."

# --- Check 2: MLflow /health endpoint ---
_mlflow_is_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=mlflow,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:5000/health')" 2>/dev/null
}

log_info "[mlflow/healthcheck] Checking MLflow health endpoint..."
retry_with_timeout 120 10 _mlflow_is_ready
log_info "[mlflow/healthcheck] MLflow is responding to health checks."

# --- Check 3: PVCs are bound ---
log_info "[mlflow/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[mlflow/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[mlflow/healthcheck] All PVCs are Bound."
else
    log_warn "[mlflow/healthcheck] Not all PVCs are Bound."
    exit 1
fi
