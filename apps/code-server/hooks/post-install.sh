#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

source "${BOOTSTRAP_DIR}/lib/logging.sh"
source "${BOOTSTRAP_DIR}/lib/constants.sh"
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}code-server"

log_info "[code-server/post-install] Waiting for code-server to be ready..."

_get_code_server_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=code-server,app.kubernetes.io/component=code-server \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_code_server_pod_ready() {
    local pod
    pod="$(_get_code_server_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _code_server_pod_ready

code_server_pod="$(_get_code_server_pod)"
log_info "[code-server/post-install] code-server pod ready: ${code_server_pod}"

local_port="${PARAM_CODE_SERVER_NODEPORT:-30080}"
log_info "[code-server/post-install] Web IDE: http://<VM-IP>:${local_port}"
log_info "[code-server/post-install] Login with the configured password."
