#!/usr/bin/env bash
# post-install.sh — Ghost post-install hook.
# Waits for the Ghost pod to be ready and logs access information.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}ghost"

log_info "[ghost/post-install] Waiting for Ghost to be ready..."

# --- Wait for Ghost pod to be ready ---
_get_ghost_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=ghost,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_ghost_pod_ready() {
    local pod
    pod="$(_get_ghost_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _ghost_pod_ready

ghost_pod="$(_get_ghost_pod)"
log_info "[ghost/post-install] Ghost pod ready: ${ghost_pod}"

# --- Log access info ---
local_port="${PARAM_HTTP_NODEPORT:-${DEFAULT_HTTP_NODEPORT}}"
log_info "[ghost/post-install] Blog: http://<VM-IP>:${local_port}"
log_info "[ghost/post-install] Admin: http://<VM-IP>:${local_port}/ghost/"
log_info "[ghost/post-install] Create your admin account on first visit to /ghost/"
