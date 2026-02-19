#!/usr/bin/env bash
# healthcheck.sh — Joomla-specific health checks.
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

local_namespace="${HELM_NAMESPACE_PREFIX}joomla"

# --- Check 1: MariaDB accepts connections ---
_mariadb_responds() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=joomla,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        healthcheck.sh --connect 2>/dev/null
}

log_info "[joomla/healthcheck] Checking MariaDB connectivity..."
retry_with_timeout 120 10 _mariadb_responds
log_info "[joomla/healthcheck] MariaDB is accepting connections."

# --- Check 2: Joomla HTTP response ---
_joomla_responds() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=joomla,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    local status_code
    status_code="$(kubectl exec -n "${local_namespace}" "$pod" -- \
        curl -sS -o /dev/null -w '%{http_code}' \
        --max-time 10 \
        "http://localhost/" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

log_info "[joomla/healthcheck] Checking Joomla HTTP response..."
retry_with_timeout 120 10 _joomla_responds
log_info "[joomla/healthcheck] Joomla is responding on HTTP."

# --- Check 3: PVCs are bound ---
log_info "[joomla/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[joomla/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[joomla/healthcheck] All PVCs are Bound."
else
    log_warn "[joomla/healthcheck] Not all PVCs are Bound."
    exit 1
fi
