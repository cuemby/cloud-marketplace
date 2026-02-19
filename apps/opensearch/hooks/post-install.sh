#!/usr/bin/env bash
# post-install.sh — OpenSearch post-install hook.
# Waits for the pod to be ready and logs access information.
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

log_info "[opensearch/post-install] Waiting for OpenSearch to be ready..."

# --- Wait for OpenSearch pod to be ready ---
_get_opensearch_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=opensearch,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_opensearch_pod_ready() {
    local pod
    pod="$(_get_opensearch_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 600 10 _opensearch_pod_ready

opensearch_pod="$(_get_opensearch_pod)"
log_info "[opensearch/post-install] OpenSearch pod ready: ${opensearch_pod}"

# --- Log access info ---
local_port="${PARAM_OPENSEARCH_NODEPORT:-30920}"
log_info "[opensearch/post-install] OpenSearch API: http://<VM-IP>:${local_port}"
log_info "[opensearch/post-install] Cluster health: curl http://<VM-IP>:${local_port}/_cluster/health?pretty"
log_info "[opensearch/post-install] Security plugin is disabled. Enable it for production use."
