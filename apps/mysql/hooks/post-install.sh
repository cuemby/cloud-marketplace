#!/usr/bin/env bash
# post-install.sh — MySQL post-install hook.
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

local_namespace="${HELM_NAMESPACE_PREFIX}mysql"

log_info "[mysql/post-install] Waiting for MySQL to be ready..."

# --- Wait for MySQL pod to be ready ---
_get_mysql_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=mysql,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_mysql_pod_ready() {
    local pod
    pod="$(_get_mysql_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _mysql_pod_ready

mysql_pod="$(_get_mysql_pod)"
log_info "[mysql/post-install] MySQL pod ready: ${mysql_pod}"

# --- Log connection info ---
local_port="${PARAM_MYSQL_NODEPORT:-30306}"
log_info "[mysql/post-install] Connection: mysql -h <VM-IP> -P ${local_port} -u ${PARAM_MYSQL_USER:-mysql} -p"
log_info "[mysql/post-install] Port: ${local_port} (NodePort)"
log_info "[mysql/post-install] User: ${PARAM_MYSQL_USER:-mysql}"
log_info "[mysql/post-install] Database: ${PARAM_MYSQL_DATABASE:-mysql}"
