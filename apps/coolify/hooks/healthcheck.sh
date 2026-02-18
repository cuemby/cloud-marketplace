#!/usr/bin/env bash
# healthcheck.sh — Coolify-specific health checks.
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

local_namespace="${HELM_NAMESPACE_PREFIX}coolify"

# --- Check 1: PostgreSQL accepts connections ---
_postgres_responds() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=coolify,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        pg_isready -U coolify 2>/dev/null
}

log_info "[coolify/healthcheck] Checking PostgreSQL connectivity..."
retry_with_timeout 120 10 _postgres_responds
log_info "[coolify/healthcheck] PostgreSQL is accepting connections."

# --- Check 2: Coolify HTTP response ---
_coolify_responds() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=coolify,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    local status_code
    status_code="$(kubectl exec -n "${local_namespace}" "$pod" -- \
        curl -sS -o /dev/null -w '%{http_code}' \
        --max-time 10 \
        "http://localhost:8080" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

log_info "[coolify/healthcheck] Checking Coolify HTTP response..."
retry_with_timeout 120 10 _coolify_responds
log_info "[coolify/healthcheck] Coolify is responding on HTTP."

# --- Check 3: PVCs are bound ---
log_info "[coolify/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[coolify/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[coolify/healthcheck] All PVCs are Bound."
else
    log_warn "[coolify/healthcheck] Not all PVCs are Bound."
    exit 1
fi
