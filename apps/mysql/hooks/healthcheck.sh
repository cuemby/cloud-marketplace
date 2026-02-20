#!/usr/bin/env bash
# healthcheck.sh — MySQL-specific health checks.
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

local_namespace="${HELM_NAMESPACE_PREFIX}mysql"

# --- Check 1: MySQL accepts connections ---
_mysql_is_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=mysql,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        mysqladmin ping -h 127.0.0.1 2>/dev/null
}

log_info "[mysql/healthcheck] Checking MySQL connectivity..."
retry_with_timeout 120 10 _mysql_is_ready
log_info "[mysql/healthcheck] MySQL is accepting connections."

# --- Check 2: SQL query succeeds ---
_mysql_query_works() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=mysql,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        sh -c 'mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1" 2>/dev/null' \
        | grep -q "1"
}

log_info "[mysql/healthcheck] Verifying SQL query execution..."
retry_with_timeout 120 10 _mysql_query_works
log_info "[mysql/healthcheck] MySQL query execution verified."

# --- Check 3: PVCs are bound ---
log_info "[mysql/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[mysql/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[mysql/healthcheck] All PVCs are Bound."
else
    log_warn "[mysql/healthcheck] Not all PVCs are Bound."
    exit 1
fi
