#!/usr/bin/env bash
# healthcheck.sh — Neo4j-specific health checks.
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

local_namespace="${HELM_NAMESPACE_PREFIX}neo4j"

# --- Check 1: Neo4j HTTP endpoint is responding ---
_neo4j_http_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=neo4j,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        curl -sf http://localhost:7474 >/dev/null 2>&1
}

log_info "[neo4j/healthcheck] Checking Neo4j HTTP endpoint..."
retry_with_timeout 120 10 _neo4j_http_ready
log_info "[neo4j/healthcheck] Neo4j HTTP endpoint is responding."

# --- Check 2: Cypher query works (write operation) ---
_neo4j_cypher_works() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=neo4j,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        cypher-shell -u neo4j -p "${PARAM_NEO4J_AUTH_PASSWORD}" \
        "RETURN 1 AS healthcheck;" 2>/dev/null | grep -q "healthcheck"
}

log_info "[neo4j/healthcheck] Verifying Cypher query execution..."
retry_with_timeout 120 10 _neo4j_cypher_works
log_info "[neo4j/healthcheck] Neo4j Cypher query execution verified."

# --- Check 3: PVCs are bound ---
log_info "[neo4j/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[neo4j/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[neo4j/healthcheck] All PVCs are Bound."
else
    log_warn "[neo4j/healthcheck] Not all PVCs are Bound."
    exit 1
fi
