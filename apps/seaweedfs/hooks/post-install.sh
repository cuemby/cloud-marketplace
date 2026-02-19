#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

source "${BOOTSTRAP_DIR}/lib/logging.sh"
source "${BOOTSTRAP_DIR}/lib/constants.sh"
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}seaweedfs"

log_info "[seaweedfs/post-install] Waiting for SeaweedFS to be ready..."

_get_seaweedfs_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=seaweedfs,app.kubernetes.io/component=storage \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_seaweedfs_pod_ready() {
    local pod
    pod="$(_get_seaweedfs_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _seaweedfs_pod_ready

seaweedfs_pod="$(_get_seaweedfs_pod)"
log_info "[seaweedfs/post-install] SeaweedFS pod ready: ${seaweedfs_pod}"

local_s3_port="${PARAM_SEAWEEDFS_S3_NODEPORT:-30833}"
local_filer_port="${PARAM_SEAWEEDFS_FILER_NODEPORT:-30888}"
local_master_port="${PARAM_SEAWEEDFS_MASTER_NODEPORT:-30933}"
log_info "[seaweedfs/post-install] S3 API: http://<VM-IP>:${local_s3_port}"
log_info "[seaweedfs/post-install] Filer: http://<VM-IP>:${local_filer_port}"
log_info "[seaweedfs/post-install] Master: http://<VM-IP>:${local_master_port}"
