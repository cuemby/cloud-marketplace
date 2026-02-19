#!/usr/bin/env bash
# post-install.sh — Harbor post-install hook.
# Waits for all Harbor components to be ready and logs access information.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}harbor"

# --- Wait for Harbor Core pod to be ready ---
log_info "[harbor/post-install] Waiting for Harbor Core to be ready..."

_get_core_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=harbor,app.kubernetes.io/component=core \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_core_pod_ready() {
    local pod
    pod="$(_get_core_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 600 10 _core_pod_ready

core_pod="$(_get_core_pod)"
log_info "[harbor/post-install] Harbor Core pod ready: ${core_pod}"

# --- Wait for Portal pod to be ready ---
log_info "[harbor/post-install] Waiting for Harbor Portal to be ready..."

_portal_pod_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=harbor,app.kubernetes.io/component=portal \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _portal_pod_ready
log_info "[harbor/post-install] Harbor Portal is ready."

# --- Log access info ---
local_port="${PARAM_HTTPS_NODEPORT:-${DEFAULT_HTTPS_NODEPORT}}"
log_info "[harbor/post-install] Harbor Web UI: http://<VM-IP>:${local_port}"
log_info "[harbor/post-install] Harbor API: http://<VM-IP>:${local_port}/api/v2.0/health"
log_info "[harbor/post-install] Username: admin"
log_info "[harbor/post-install] Docker login: docker login <VM-IP>:${local_port}"
