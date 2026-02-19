#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

source "${BOOTSTRAP_DIR}/lib/logging.sh"
source "${BOOTSTRAP_DIR}/lib/constants.sh"
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}vaultwarden"

# Check 1: Vaultwarden alive endpoint
_vaultwarden_health_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=vaultwarden,app.kubernetes.io/component=vaultwarden \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        curl -sf http://localhost:80/alive 2>/dev/null
}

log_info "[vaultwarden/healthcheck] Checking Vaultwarden health endpoint..."
retry_with_timeout 120 10 _vaultwarden_health_ready
log_info "[vaultwarden/healthcheck] Vaultwarden health endpoint is responding."

# Check 2: PVC is bound
log_info "[vaultwarden/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[vaultwarden/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[vaultwarden/healthcheck] All PVCs are Bound."
else
    log_warn "[vaultwarden/healthcheck] Not all PVCs are Bound."
    exit 1
fi
