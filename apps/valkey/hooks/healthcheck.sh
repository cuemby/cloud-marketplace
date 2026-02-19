#!/usr/bin/env bash
# healthcheck.sh — Valkey-specific health checks.
# Called by the generic healthcheck after pod/service checks pass.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}valkey"

# --- Check 1: Valkey accepts connections ---
_valkey_is_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=valkey,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        valkey-cli -a "${PARAM_VALKEY_PASSWORD}" ping 2>/dev/null | grep -q "PONG"
}

log_info "[valkey/healthcheck] Checking Valkey connectivity..."
retry_with_timeout 120 10 _valkey_is_ready
log_info "[valkey/healthcheck] Valkey is accepting connections."

# --- Check 2: SET/GET operation succeeds ---
_valkey_setget_works() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=valkey,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        valkey-cli -a "${PARAM_VALKEY_PASSWORD}" \
        SET healthcheck_test "ok" EX 10 2>/dev/null | grep -q "OK"
}

log_info "[valkey/healthcheck] Verifying SET/GET operations..."
retry_with_timeout 120 10 _valkey_setget_works
log_info "[valkey/healthcheck] Valkey SET/GET operations verified."

# --- Check 3: PVCs are bound ---
log_info "[valkey/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[valkey/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[valkey/healthcheck] All PVCs are Bound."
else
    log_warn "[valkey/healthcheck] Not all PVCs are Bound."
    exit 1
fi
