#!/usr/bin/env bash
# healthcheck.sh — OpenSearch-specific health checks.
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

local_namespace="${HELM_NAMESPACE_PREFIX}opensearch"

# --- Check 1: OpenSearch cluster health ---
_opensearch_is_healthy() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=opensearch,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    local status
    status="$(kubectl exec -n "${local_namespace}" "$pod" -- \
        curl -sf http://127.0.0.1:9200/_cluster/health 2>/dev/null)"
    [[ -n "$status" ]] && echo "$status" | grep -qE '"status"\s*:\s*"(green|yellow)"'
}

log_info "[opensearch/healthcheck] Checking OpenSearch cluster health..."
retry_with_timeout 120 10 _opensearch_is_healthy
log_info "[opensearch/healthcheck] OpenSearch cluster is healthy."

# --- Check 2: PVCs are bound ---
log_info "[opensearch/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[opensearch/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[opensearch/healthcheck] All PVCs are Bound."
else
    log_warn "[opensearch/healthcheck] Not all PVCs are Bound."
    exit 1
fi
