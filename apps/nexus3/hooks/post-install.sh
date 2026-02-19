#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

source "${BOOTSTRAP_DIR}/lib/logging.sh"
source "${BOOTSTRAP_DIR}/lib/constants.sh"
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}nexus3"

log_info "[nexus3/post-install] Waiting for Nexus Repository to be ready..."

_get_nexus_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=nexus3,app.kubernetes.io/component=nexus3 \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_nexus_pod_ready() {
    local pod
    pod="$(_get_nexus_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 600 15 _nexus_pod_ready

nexus_pod="$(_get_nexus_pod)"
log_info "[nexus3/post-install] Nexus Repository pod ready: ${nexus_pod}"

local_port="${PARAM_NEXUS_NODEPORT:-30081}"
log_info "[nexus3/post-install] Web UI: http://<VM-IP>:${local_port}"
log_info "[nexus3/post-install] Initial admin password is at /nexus-data/admin.password inside the container."
log_info "[nexus3/post-install] Retrieve it with: kubectl exec -n ${local_namespace} ${nexus_pod} -- cat /nexus-data/admin.password"
