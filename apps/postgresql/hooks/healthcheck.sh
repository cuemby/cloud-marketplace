#!/usr/bin/env bash
# healthcheck.sh — PostgreSQL-specific health checks.
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

local_namespace="${HELM_NAMESPACE_PREFIX}postgresql"

# --- Check 1: PostgreSQL accepts connections ---
_pg_is_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=postgresql,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        pg_isready -U "${PARAM_POSTGRES_USER:-postgres}" 2>/dev/null
}

log_info "[postgresql/healthcheck] Checking PostgreSQL connectivity..."
retry_with_timeout 120 10 _pg_is_ready
log_info "[postgresql/healthcheck] PostgreSQL is accepting connections."

# --- Check 2: SQL query succeeds ---
_pg_query_works() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=postgresql,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        psql -U "${PARAM_POSTGRES_USER:-postgres}" \
        -d "${PARAM_POSTGRES_DB:-postgres}" \
        -c "SELECT 1" 2>/dev/null | grep -q "1"
}

log_info "[postgresql/healthcheck] Verifying SQL query execution..."
retry_with_timeout 120 10 _pg_query_works
log_info "[postgresql/healthcheck] PostgreSQL query execution verified."

# --- Check 3: PVCs are bound ---
log_info "[postgresql/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[postgresql/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[postgresql/healthcheck] All PVCs are Bound."
else
    log_warn "[postgresql/healthcheck] Not all PVCs are Bound."
    exit 1
fi
