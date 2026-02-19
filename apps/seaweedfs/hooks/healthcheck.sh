#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

source "${BOOTSTRAP_DIR}/lib/logging.sh"
source "${BOOTSTRAP_DIR}/lib/constants.sh"
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}seaweedfs"

# Check 1: SeaweedFS pod is Ready (Kubernetes HTTP probes verify /cluster/status)
_seaweedfs_master_ready() {
    local ready
    ready="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=seaweedfs,app.kubernetes.io/component=storage \
        -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)"
    [[ "$ready" == "True" ]]
}

log_info "[seaweedfs/healthcheck] Checking master cluster status..."
retry_with_timeout 120 10 _seaweedfs_master_ready
log_info "[seaweedfs/healthcheck] Master cluster is healthy."

# Check 2: S3 API port is listening (verify via service endpoint)
_seaweedfs_s3_ready() {
    local endpoints
    endpoints="$(kubectl get endpoints seaweedfs-s3 -n "${local_namespace}" \
        -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)"
    [[ -n "$endpoints" ]]
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
