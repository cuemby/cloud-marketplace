#!/usr/bin/env bash
# healthcheck.sh — Percona Server for MySQL health checks.
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

local_namespace="${HELM_NAMESPACE_PREFIX}percona-mysql"

# --- Check 1: Percona MySQL accepts connections ---
_percona_is_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=percona-mysql,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        mysqladmin ping -u root -p"${PARAM_PERCONA_ROOT_PASSWORD}" 2>/dev/null
}

log_info "[percona-mysql/healthcheck] Checking Percona MySQL connectivity..."
retry_with_timeout 120 10 _percona_is_ready
log_info "[percona-mysql/healthcheck] Percona MySQL is accepting connections."

# --- Check 2: SQL query succeeds ---
_percona_query_works() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=percona-mysql,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        mysql -u root -p"${PARAM_PERCONA_ROOT_PASSWORD}" \
        -e "SELECT 1" 2>/dev/null | grep -q "1"
}

log_info "[percona-mysql/healthcheck] Verifying SQL query execution..."
retry_with_timeout 120 10 _percona_query_works
log_info "[percona-mysql/healthcheck] Percona MySQL query execution verified."

# --- Check 3: PVCs are bound ---
log_info "[percona-mysql/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[percona-mysql/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[percona-mysql/healthcheck] All PVCs are Bound."
else
    log_warn "[percona-mysql/healthcheck] Not all PVCs are Bound."
    exit 1
fi
