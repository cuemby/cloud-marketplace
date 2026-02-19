#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

source "${BOOTSTRAP_DIR}/lib/logging.sh"
source "${BOOTSTRAP_DIR}/lib/constants.sh"
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}seaweedfs"

# Check 1: Master cluster status endpoint
_seaweedfs_master_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=seaweedfs,app.kubernetes.io/component=storage \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        curl -sf http://localhost:9333/cluster/status 2>/dev/null | grep -q "IsLeader"
}

log_info "[seaweedfs/healthcheck] Checking master cluster status..."
retry_with_timeout 120 10 _seaweedfs_master_ready
log_info "[seaweedfs/healthcheck] Master cluster is healthy."

# Check 2: S3 API endpoint responding
_seaweedfs_s3_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=seaweedfs,app.kubernetes.io/component=storage \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        curl -sf -o /dev/null http://localhost:8333/ 2>/dev/null
}

log_info "[seaweedfs/healthcheck] Checking S3 API endpoint..."
retry_with_timeout 120 10 _seaweedfs_s3_ready
log_info "[seaweedfs/healthcheck] S3 API is responding."

# Check 3: PVC is bound
log_info "[seaweedfs/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[seaweedfs/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[seaweedfs/healthcheck] All PVCs are Bound."
else
    log_warn "[seaweedfs/healthcheck] Not all PVCs are Bound."
    exit 1
fi
