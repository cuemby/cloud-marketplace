#!/usr/bin/env bash
# post-install.sh — Neo4j post-install hook.
# Waits for the pod to be ready and logs connection info.
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

log_info "[neo4j/post-install] Waiting for Neo4j to be ready..."

# --- Wait for Neo4j pod to be ready ---
_get_neo4j_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=neo4j,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_neo4j_pod_ready() {
    local pod
    pod="$(_get_neo4j_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _neo4j_pod_ready

neo4j_pod="$(_get_neo4j_pod)"
log_info "[neo4j/post-install] Neo4j pod ready: ${neo4j_pod}"

# --- Log connection info ---
http_port="${PARAM_NEO4J_HTTP_NODEPORT:-30474}"
bolt_port="${PARAM_NEO4J_BOLT_NODEPORT:-30687}"
log_info "[neo4j/post-install] Browser: http://<VM-IP>:${http_port}"
log_info "[neo4j/post-install] Bolt: bolt://<VM-IP>:${bolt_port}"
log_info "[neo4j/post-install] User: neo4j"
