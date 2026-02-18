#!/usr/bin/env bash
# post-install.sh — PostgreSQL post-install hook.
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

local_namespace="${HELM_NAMESPACE_PREFIX}postgresql"

log_info "[postgresql/post-install] Waiting for PostgreSQL to be ready..."

# --- Wait for PostgreSQL pod to be ready ---
_get_pg_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=postgresql,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_pg_pod_ready() {
    local pod
    pod="$(_get_pg_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _pg_pod_ready

pg_pod="$(_get_pg_pod)"
log_info "[postgresql/post-install] PostgreSQL pod ready: ${pg_pod}"

# --- Log connection info ---
local_port="${PARAM_POSTGRESQL_NODEPORT:-30432}"
log_info "[postgresql/post-install] Connection: psql -h <VM-IP> -p ${local_port} -U ${PARAM_POSTGRES_USER:-postgres} -d ${PARAM_POSTGRES_DB:-postgres}"
log_info "[postgresql/post-install] Port: ${local_port} (NodePort)"
log_info "[postgresql/post-install] User: ${PARAM_POSTGRES_USER:-postgres}"
log_info "[postgresql/post-install] Database: ${PARAM_POSTGRES_DB:-postgres}"
