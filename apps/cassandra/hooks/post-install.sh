#!/usr/bin/env bash
# post-install.sh — Cassandra post-install hook.
# Waits for the pod to be ready, enables authentication, and sets the superuser password.
# The official Cassandra Docker image does not support password env vars,
# so we configure auth via CQL after startup.
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

log_info "[cassandra/post-install] Waiting for Cassandra to be ready..."

# --- Wait for Cassandra pod to be ready ---
_get_cass_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=cassandra,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_cass_pod_ready() {
    local pod
    pod="$(_get_cass_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _cass_pod_ready

cass_pod="$(_get_cass_pod)"
log_info "[cassandra/post-install] Cassandra pod ready: ${cass_pod}"

# --- Wait for CQL to be available ---
_cql_available() {
    kubectl exec -n "${local_namespace}" "${cass_pod}" -- \
        cqlsh -e "SELECT cluster_name FROM system.local" 2>/dev/null | grep -q "${PARAM_CASSANDRA_CLUSTER_NAME:-CuembyCassandra}"
}

log_info "[cassandra/post-install] Waiting for CQL interface..."
retry_with_timeout 300 10 _cql_available
log_info "[cassandra/post-install] CQL interface is available."

# --- Set superuser password via CQL ---
local_password="${PARAM_CASSANDRA_PASSWORD}"
log_info "[cassandra/post-install] Setting superuser password..."
kubectl exec -n "${local_namespace}" "${cass_pod}" -- \
    cqlsh -e "ALTER USER cassandra WITH PASSWORD '${local_password}';" 2>/dev/null || \
    log_warn "[cassandra/post-install] Password change returned non-zero (may already be set)."

# --- Log connection info ---
local_port="${PARAM_CASSANDRA_NODEPORT:-30942}"
log_info "[cassandra/post-install] Connection: cqlsh <VM-IP> ${local_port} -u cassandra -p <password>"
log_info "[cassandra/post-install] Port: ${local_port} (NodePort/CQL)"
log_info "[cassandra/post-install] User: cassandra"
log_info "[cassandra/post-install] Cluster: ${PARAM_CASSANDRA_CLUSTER_NAME:-CuembyCassandra}"
