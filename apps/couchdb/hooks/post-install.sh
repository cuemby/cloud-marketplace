#!/usr/bin/env bash
# post-install.sh — CouchDB post-install hook.
# Waits for the pod to be ready, runs single-node cluster setup, and logs access info.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}couchdb"

log_info "[couchdb/post-install] Waiting for CouchDB to be ready..."

# --- Wait for CouchDB pod to be ready ---
_get_couchdb_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=couchdb,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_couchdb_pod_ready() {
    local pod
    pod="$(_get_couchdb_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _couchdb_pod_ready

couchdb_pod="$(_get_couchdb_pod)"
log_info "[couchdb/post-install] CouchDB pod ready: ${couchdb_pod}"

# --- Single-node cluster setup (creates system databases) ---
_cluster_setup() {
    kubectl exec -n "${local_namespace}" "${couchdb_pod}" -- \
        curl -sf -X POST http://127.0.0.1:5984/_cluster_setup \
        -H "Content-Type: application/json" \
        -u "${PARAM_COUCHDB_USER:-admin}:${PARAM_COUCHDB_PASSWORD}" \
        -d '{"action":"enable_single_node","bind_address":"0.0.0.0","port":5984}' \
        >/dev/null 2>&1
}

log_info "[couchdb/post-install] Running single-node cluster setup..."
retry_with_timeout 60 5 _cluster_setup
log_info "[couchdb/post-install] Single-node setup complete."

# --- Log access info ---
local_port="${PARAM_COUCHDB_NODEPORT:-30594}"
log_info "[couchdb/post-install] CouchDB API: http://<VM-IP>:${local_port}"
log_info "[couchdb/post-install] Fauxton UI: http://<VM-IP>:${local_port}/_utils"
log_info "[couchdb/post-install] User: ${PARAM_COUCHDB_USER:-admin}"
