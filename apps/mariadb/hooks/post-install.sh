#!/usr/bin/env bash
# post-install.sh — MariaDB post-install hook.
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

local_namespace="${HELM_NAMESPACE_PREFIX}mariadb"

log_info "[mariadb/post-install] Waiting for MariaDB to be ready..."

# --- Wait for MariaDB pod to be ready ---
_get_mariadb_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=mariadb,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_mariadb_pod_ready() {
    local pod
    pod="$(_get_mariadb_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _mariadb_pod_ready

mariadb_pod="$(_get_mariadb_pod)"
log_info "[mariadb/post-install] MariaDB pod ready: ${mariadb_pod}"

# --- Log connection info ---
local_port="${PARAM_MARIADB_NODEPORT:-30306}"
log_info "[mariadb/post-install] Connection: mysql -h <VM-IP> -P ${local_port} -u ${PARAM_MARIADB_USER:-mariadb} -p"
log_info "[mariadb/post-install] Port: ${local_port} (NodePort)"
log_info "[mariadb/post-install] User: ${PARAM_MARIADB_USER:-mariadb}"
log_info "[mariadb/post-install] Database: ${PARAM_MARIADB_DATABASE:-mariadb}"
