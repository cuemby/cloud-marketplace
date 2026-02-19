#!/usr/bin/env bash
# post-install.sh — Percona Server for MySQL post-install hook.
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

local_namespace="${HELM_NAMESPACE_PREFIX}percona-mysql"

log_info "[percona-mysql/post-install] Waiting for Percona MySQL to be ready..."

# --- Wait for Percona MySQL pod to be ready ---
_get_percona_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=percona-mysql,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_percona_pod_ready() {
    local pod
    pod="$(_get_percona_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _percona_pod_ready

percona_pod="$(_get_percona_pod)"
log_info "[percona-mysql/post-install] Percona MySQL pod ready: ${percona_pod}"

# --- Log connection info ---
local_port="${PARAM_PERCONA_NODEPORT:-30306}"
log_info "[percona-mysql/post-install] Connection: mysql -h <VM-IP> -P ${local_port} -u ${PARAM_PERCONA_USER:-percona} -p"
log_info "[percona-mysql/post-install] Port: ${local_port} (NodePort)"
log_info "[percona-mysql/post-install] User: ${PARAM_PERCONA_USER:-percona}"
log_info "[percona-mysql/post-install] Database: ${PARAM_PERCONA_DATABASE:-percona}"
