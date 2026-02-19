#!/usr/bin/env bash
# healthcheck.sh — Odoo-specific health checks.
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

local_namespace="${HELM_NAMESPACE_PREFIX}odoo"

# --- Check 1: PostgreSQL accepts connections ---
_pg_is_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=odoo,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        pg_isready -U odoo 2>/dev/null
}

log_info "[odoo/healthcheck] Checking PostgreSQL connectivity..."
retry_with_timeout 120 10 _pg_is_ready
log_info "[odoo/healthcheck] PostgreSQL is accepting connections."

# --- Check 2: Odoo web endpoint ---
_odoo_is_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=odoo,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    local status_code
    status_code="$(kubectl exec -n "${local_namespace}" "$pod" -- \
        curl -sS -o /dev/null -w '%{http_code}' --max-time 10 \
        http://127.0.0.1:8069/web/database/selector 2>/dev/null || true)"
    # Accept any HTTP response (200, 303 redirect, or even 500 during DB init)
    [[ -n "$status_code" && "$status_code" != "000" ]]
}

log_info "[odoo/healthcheck] Checking Odoo health endpoint..."
retry_with_timeout 120 10 _odoo_is_ready
log_info "[odoo/healthcheck] Odoo is responding to health checks."

# --- Check 3: PVCs are bound ---
log_info "[odoo/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[odoo/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[odoo/healthcheck] All PVCs are Bound."
else
    log_warn "[odoo/healthcheck] Not all PVCs are Bound."
    exit 1
fi
