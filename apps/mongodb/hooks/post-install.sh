#!/usr/bin/env bash
# post-install.sh — MongoDB post-install hook.
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

local_namespace="${HELM_NAMESPACE_PREFIX}mongodb"

log_info "[mongodb/post-install] Waiting for MongoDB to be ready..."

# --- Wait for MongoDB pod to be ready ---
_get_mongodb_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=mongodb,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_mongodb_pod_ready() {
    local pod
    pod="$(_get_mongodb_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _mongodb_pod_ready

mongodb_pod="$(_get_mongodb_pod)"
log_info "[mongodb/post-install] MongoDB pod ready: ${mongodb_pod}"

# --- Log connection info ---
local_port="${PARAM_MONGODB_NODEPORT:-30017}"
log_info "[mongodb/post-install] Connection: mongosh mongodb://${PARAM_MONGO_INITDB_ROOT_USERNAME:-admin}:<password>@<VM-IP>:${local_port}/admin"
log_info "[mongodb/post-install] Port: ${local_port} (NodePort)"
log_info "[mongodb/post-install] User: ${PARAM_MONGO_INITDB_ROOT_USERNAME:-admin}"
