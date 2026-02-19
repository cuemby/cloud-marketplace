#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

source "${BOOTSTRAP_DIR}/lib/logging.sh"
source "${BOOTSTRAP_DIR}/lib/constants.sh"
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}portainer"

log_info "[portainer/post-install] Waiting for Portainer CE to be ready..."

_get_portainer_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=portainer,app.kubernetes.io/component=portainer \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_portainer_pod_ready() {
    local pod
    pod="$(_get_portainer_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _portainer_pod_ready

portainer_pod="$(_get_portainer_pod)"
log_info "[portainer/post-install] Portainer CE pod ready: ${portainer_pod}"

local_port="${PARAM_PORTAINER_NODEPORT:-30900}"
log_info "[portainer/post-install] Web UI: http://<VM-IP>:${local_port}"
log_info "[portainer/post-install] Create your admin account on first login."
