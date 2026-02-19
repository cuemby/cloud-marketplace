#!/usr/bin/env bash
# healthcheck.sh — SonarQube-specific health checks.
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

local_namespace="${HELM_NAMESPACE_PREFIX}sonarqube"

# --- Check 1: PostgreSQL accepts connections ---
_pg_is_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=sonarqube,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        pg_isready -U sonarqube 2>/dev/null
}

log_info "[sonarqube/healthcheck] Checking PostgreSQL connectivity..."
retry_with_timeout 120 10 _pg_is_ready
log_info "[sonarqube/healthcheck] PostgreSQL is accepting connections."

# --- Check 2: SonarQube HTTP API ---
_sonarqube_is_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=sonarqube,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    local status
    status="$(kubectl exec -n "${local_namespace}" "$pod" -- \
        curl -sf http://127.0.0.1:9000/api/system/status 2>/dev/null)" || return 1
    echo "$status" | grep -q '"status":"UP"'
}

log_info "[sonarqube/healthcheck] Checking SonarQube API status..."
retry_with_timeout 120 10 _sonarqube_is_ready
log_info "[sonarqube/healthcheck] SonarQube API reports status UP."

# --- Check 3: PVCs are bound ---
log_info "[sonarqube/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[sonarqube/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[sonarqube/healthcheck] All PVCs are Bound."
else
    log_warn "[sonarqube/healthcheck] Not all PVCs are Bound."
    exit 1
fi
