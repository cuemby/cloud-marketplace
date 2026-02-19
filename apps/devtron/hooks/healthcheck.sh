#!/usr/bin/env bash
# healthcheck.sh — Devtron health checks.
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

local_namespace="${HELM_NAMESPACE_PREFIX}devtron"

# --- Check 1: PostgreSQL accepts connections ---
_pg_is_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=devtron,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        pg_isready -U postgres 2>/dev/null
}

log_info "[devtron/healthcheck] Checking PostgreSQL connectivity..."
retry_with_timeout 120 10 _pg_is_ready
log_info "[devtron/healthcheck] PostgreSQL is accepting connections."

# --- Check 2: NATS monitoring endpoint responds ---
_nats_is_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=devtron,app.kubernetes.io/component=nats \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        wget -q -O /dev/null --spider http://localhost:8222/ 2>/dev/null
}

log_info "[devtron/healthcheck] Checking NATS connectivity..."
retry_with_timeout 120 10 _nats_is_ready
log_info "[devtron/healthcheck] NATS is responding."

# --- Check 3: Orchestrator /health endpoint responds ---
_orchestrator_healthy() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=devtron,app.kubernetes.io/component=orchestrator \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        wget -q -O /dev/null --spider http://localhost:8080/health 2>/dev/null
}

log_info "[devtron/healthcheck] Checking Devtron orchestrator health..."
retry_with_timeout 120 10 _orchestrator_healthy
log_info "[devtron/healthcheck] Devtron orchestrator is healthy."

# --- Check 4: Dashboard responds ---
_dashboard_healthy() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=devtron,app.kubernetes.io/component=dashboard \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        wget -q -O /dev/null --spider http://localhost:8080/ 2>/dev/null
}

log_info "[devtron/healthcheck] Checking Devtron dashboard..."
retry_with_timeout 120 10 _dashboard_healthy
log_info "[devtron/healthcheck] Devtron dashboard is responding."

# --- Check 5: PVCs are bound ---
log_info "[devtron/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[devtron/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[devtron/healthcheck] All PVCs are Bound."
else
    log_warn "[devtron/healthcheck] Not all PVCs are Bound."
    exit 1
fi
