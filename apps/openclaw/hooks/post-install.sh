#!/usr/bin/env bash
# post-install.sh — OpenClaw post-install hook.
# Waits for pod readiness and logs access information.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}openclaw"

log_info "[openclaw/post-install] Waiting for OpenClaw to be ready..."

_get_openclaw_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=openclaw,app.kubernetes.io/component=gateway \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_openclaw_pod_ready() {
    local pod
    pod="$(_get_openclaw_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _openclaw_pod_ready

openclaw_pod="$(_get_openclaw_pod)"
log_info "[openclaw/post-install] OpenClaw pod ready: ${openclaw_pod}"

local_port="${PARAM_OPENCLAW_NODEPORT:-30789}"
log_info "[openclaw/post-install] Gateway: ws://<VM-IP>:${local_port}"
log_info "[openclaw/post-install] Port: ${local_port} (NodePort)"
log_info "[openclaw/post-install] LLM Provider: ${PARAM_OPENCLAW_LLM_PROVIDER:-anthropic}"
