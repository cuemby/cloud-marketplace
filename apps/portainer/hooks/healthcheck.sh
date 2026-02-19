#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

source "${BOOTSTRAP_DIR}/lib/logging.sh"
source "${BOOTSTRAP_DIR}/lib/constants.sh"
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}portainer"

# Check 1: Portainer pod is Ready (scratch image — cannot exec into it)
# Kubernetes HTTP probes on /api/status verify the Portainer API is responding.
_portainer_api_ready() {
    local ready
    ready="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=portainer,app.kubernetes.io/component=portainer \
        -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)"
    [[ "$ready" == "True" ]]
}

log_info "[portainer/healthcheck] Checking Portainer API status..."
retry_with_timeout 120 10 _portainer_api_ready
log_info "[portainer/healthcheck] Portainer API is responding."

# Check 2: PVC is bound
log_info "[portainer/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[portainer/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[portainer/healthcheck] All PVCs are Bound."
else
    log_warn "[portainer/healthcheck] Not all PVCs are Bound."
    exit 1
fi
