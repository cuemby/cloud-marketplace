#!/usr/bin/env bash
# healthcheck.sh — Cassandra-specific health checks.
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

local_namespace="${HELM_NAMESPACE_PREFIX}cassandra"

# --- Check 1: Cassandra node is Up/Normal ---
_cass_node_up() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=cassandra,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        nodetool status 2>/dev/null | grep -q "^UN"
}

log_info "[cassandra/healthcheck] Checking Cassandra node status..."
retry_with_timeout 120 10 _cass_node_up
log_info "[cassandra/healthcheck] Cassandra node is Up/Normal."

# --- Check 2: CQL query succeeds ---
_cql_query_works() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=cassandra,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        cqlsh -e "SELECT cluster_name FROM system.local" 2>/dev/null | grep -q "cluster_name"
}

log_info "[cassandra/healthcheck] Verifying CQL query execution..."
retry_with_timeout 120 10 _cql_query_works
log_info "[cassandra/healthcheck] CQL query execution verified."

# --- Check 3: PVCs are bound ---
log_info "[cassandra/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[cassandra/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[cassandra/healthcheck] All PVCs are Bound."
else
    log_warn "[cassandra/healthcheck] Not all PVCs are Bound."
    exit 1
fi
