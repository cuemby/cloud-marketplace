#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

source "${BOOTSTRAP_DIR}/lib/logging.sh"
source "${BOOTSTRAP_DIR}/lib/constants.sh"
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}openbao"

# Check 1: OpenBao health endpoint
_openbao_health_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=openbao,app.kubernetes.io/component=vault \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        wget -q -O /dev/null --spider http://localhost:8200/v1/sys/health 2>/dev/null
}

log_info "[openbao/healthcheck] Checking OpenBao health endpoint..."
retry_with_timeout 120 10 _openbao_health_ready
log_info "[openbao/healthcheck] OpenBao health endpoint is responding."

# Check 2: Verify secrets engine is accessible (dev mode is initialized+unsealed)
_openbao_secrets_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=openbao,app.kubernetes.io/component=vault \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        wget -q -O- --header="X-Vault-Token: ${PARAM_OPENBAO_DEV_ROOT_TOKEN}" \
        http://localhost:8200/v1/sys/mounts 2>/dev/null | grep -q "secret/"
}

log_info "[openbao/healthcheck] Checking secrets engine..."
retry_with_timeout 120 10 _openbao_secrets_ready
log_info "[openbao/healthcheck] Secrets engine is accessible."

# Check 3: PVC is bound
log_info "[openbao/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[openbao/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[openbao/healthcheck] All PVCs are Bound."
else
    log_warn "[openbao/healthcheck] Not all PVCs are Bound."
    exit 1
fi
