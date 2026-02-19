#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

source "${BOOTSTRAP_DIR}/lib/logging.sh"
source "${BOOTSTRAP_DIR}/lib/constants.sh"
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}docker-registry"

# Check 1: Registry V2 API endpoint
_registry_api_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=docker-registry,app.kubernetes.io/component=registry \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        wget -q -O /dev/null --spider http://localhost:5000/v2/ 2>/dev/null
}

log_info "[docker-registry/healthcheck] Checking registry V2 API..."
retry_with_timeout 120 10 _registry_api_ready
log_info "[docker-registry/healthcheck] Registry V2 API is responding."

# Check 2: Catalog endpoint accessible
_registry_catalog_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=docker-registry,app.kubernetes.io/component=registry \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        wget -q -O- http://localhost:5000/v2/_catalog 2>/dev/null | grep -q "repositories"
}

log_info "[docker-registry/healthcheck] Checking catalog endpoint..."
retry_with_timeout 120 10 _registry_catalog_ready
log_info "[docker-registry/healthcheck] Catalog endpoint is accessible."

# Check 3: PVC is bound
log_info "[docker-registry/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[docker-registry/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[docker-registry/healthcheck] All PVCs are Bound."
else
    log_warn "[docker-registry/healthcheck] Not all PVCs are Bound."
    exit 1
fi
