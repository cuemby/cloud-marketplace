#!/usr/bin/env bash
# post-install.sh — Valkey post-install hook.
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

local_namespace="${HELM_NAMESPACE_PREFIX}valkey"

log_info "[valkey/post-install] Waiting for Valkey to be ready..."

# --- Wait for Valkey pod to be ready ---
_get_valkey_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=valkey,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_valkey_pod_ready() {
    local pod
    pod="$(_get_valkey_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _valkey_pod_ready

valkey_pod="$(_get_valkey_pod)"
log_info "[valkey/post-install] Valkey pod ready: ${valkey_pod}"

# --- Log connection info ---
local_port="${PARAM_VALKEY_NODEPORT:-30379}"
log_info "[valkey/post-install] Connection: valkey-cli -h <VM-IP> -p ${local_port} -a <password>"
log_info "[valkey/post-install] Port: ${local_port} (NodePort)"
log_info "[valkey/post-install] Max Memory: ${PARAM_VALKEY_MAXMEMORY:-1gb}"
log_info "[valkey/post-install] Eviction Policy: ${PARAM_VALKEY_MAXMEMORY_POLICY:-allkeys-lru}"
