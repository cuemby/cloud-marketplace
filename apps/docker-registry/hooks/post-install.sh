#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

source "${BOOTSTRAP_DIR}/lib/logging.sh"
source "${BOOTSTRAP_DIR}/lib/constants.sh"
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}docker-registry"

log_info "[docker-registry/post-install] Waiting for Docker Registry to be ready..."

_get_registry_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=docker-registry,app.kubernetes.io/component=registry \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_registry_pod_ready() {
    local pod
    pod="$(_get_registry_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _registry_pod_ready

registry_pod="$(_get_registry_pod)"
log_info "[docker-registry/post-install] Docker Registry pod ready: ${registry_pod}"

local_port="${PARAM_REGISTRY_NODEPORT:-30500}"
log_info "[docker-registry/post-install] Registry API: http://<VM-IP>:${local_port}/v2/"
log_info "[docker-registry/post-install] Push images: docker push <VM-IP>:${local_port}/<image>:<tag>"
