#!/usr/bin/env bash
# healthcheck.sh — MariaDB-specific health checks.
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

local_namespace="${HELM_NAMESPACE_PREFIX}mariadb"

# --- Check 1: MariaDB accepts connections ---
_mariadb_is_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=mariadb,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        mariadb-admin ping -u root -p"${PARAM_MARIADB_ROOT_PASSWORD}" 2>/dev/null
}

log_info "[mariadb/healthcheck] Checking MariaDB connectivity..."
retry_with_timeout 120 10 _mariadb_is_ready
log_info "[mariadb/healthcheck] MariaDB is accepting connections."

# --- Check 2: SQL query succeeds ---
_mariadb_query_works() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=mariadb,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        mariadb -u root -p"${PARAM_MARIADB_ROOT_PASSWORD}" \
        -e "SELECT 1" 2>/dev/null | grep -q "1"
}

log_info "[mariadb/healthcheck] Verifying SQL query execution..."
retry_with_timeout 120 10 _mariadb_query_works
log_info "[mariadb/healthcheck] MariaDB query execution verified."

# --- Check 3: PVCs are bound ---
log_info "[mariadb/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[mariadb/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[mariadb/healthcheck] All PVCs are Bound."
else
    log_warn "[mariadb/healthcheck] Not all PVCs are Bound."
    exit 1
fi
