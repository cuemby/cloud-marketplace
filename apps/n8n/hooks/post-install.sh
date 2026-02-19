#!/usr/bin/env bash
# post-install.sh — n8n post-install hook.
# Waits for the n8n pod to be ready and logs access information.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}n8n"

log_info "[n8n/post-install] Waiting for n8n to be ready..."

# --- Wait for n8n pod to be ready ---
_get_n8n_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=n8n,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_n8n_pod_ready() {
    local pod
    pod="$(_get_n8n_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _n8n_pod_ready

n8n_pod="$(_get_n8n_pod)"
log_info "[n8n/post-install] n8n pod ready: ${n8n_pod}"

# --- Log access info ---
local_port="${PARAM_N8N_NODEPORT:-30080}"
log_info "[n8n/post-install] n8n web UI: http://<VM-IP>:${local_port}"
log_info "[n8n/post-install] Create your owner account on first login."
