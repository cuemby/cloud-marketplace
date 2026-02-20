#!/usr/bin/env bash
# healthcheck.sh — Twenty CRM health checks.
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

local_namespace="${HELM_NAMESPACE_PREFIX}twenty"

# --- Check 1: PostgreSQL accepts connections ---
_postgres_responds() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=twenty,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        pg_isready -U twenty -d default 2>/dev/null
}

log_info "[twenty/healthcheck] Checking PostgreSQL connectivity..."
retry_with_timeout 120 10 _postgres_responds
log_info "[twenty/healthcheck] PostgreSQL is accepting connections."

# --- Check 2: Twenty app responds ---
_twenty_responds() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=twenty,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        curl -sS --max-time 10 "http://localhost:3000/healthz" 2>/dev/null | grep -q "ok"
}

log_info "[twenty/healthcheck] Checking Twenty CRM status..."
retry_with_timeout 120 10 _twenty_responds
log_info "[twenty/healthcheck] Twenty CRM is responding."

# --- Check 3: PVCs are bound ---
log_info "[twenty/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[twenty/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[twenty/healthcheck] All PVCs are Bound."
else
    log_warn "[twenty/healthcheck] Not all PVCs are Bound."
    exit 1
fi
