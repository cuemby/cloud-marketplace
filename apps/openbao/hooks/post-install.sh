#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

source "${BOOTSTRAP_DIR}/lib/logging.sh"
source "${BOOTSTRAP_DIR}/lib/constants.sh"
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}openbao"

log_info "[openbao/post-install] Waiting for OpenBao to be ready..."

_get_openbao_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=openbao,app.kubernetes.io/component=vault \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_openbao_pod_ready() {
    local pod
    pod="$(_get_openbao_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _openbao_pod_ready

openbao_pod="$(_get_openbao_pod)"
log_info "[openbao/post-install] OpenBao pod ready: ${openbao_pod}"

local_port="${PARAM_OPENBAO_NODEPORT:-30820}"
log_info "[openbao/post-install] Web UI: http://<VM-IP>:${local_port}/ui/"
log_info "[openbao/post-install] API: http://<VM-IP>:${local_port}/v1/"
log_info "[openbao/post-install] Running in dev mode — auto-initialized and auto-unsealed."
log_info "[openbao/post-install] Root token is set via BAO_DEV_ROOT_TOKEN_ID."
