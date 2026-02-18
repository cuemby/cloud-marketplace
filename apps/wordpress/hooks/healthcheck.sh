#!/usr/bin/env bash
# healthcheck.sh — WordPress-specific health checks.
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

local_namespace="${HELM_NAMESPACE_PREFIX}wordpress"

# --- Check 1: MariaDB accepts connections ---
_mariadb_responds() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=wordpress,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        healthcheck.sh --connect 2>/dev/null
}

log_info "[wordpress/healthcheck] Checking MariaDB connectivity..."
retry_with_timeout 120 10 _mariadb_responds
log_info "[wordpress/healthcheck] MariaDB is accepting connections."

# --- Check 2: WordPress HTTP response ---
_wp_responds() {
    local port="${PARAM_HTTP_NODEPORT:-${DEFAULT_HTTP_NODEPORT}}"
    local status_code
    status_code="$(curl -sS -o /dev/null -w '%{http_code}' \
        --max-time 10 \
        "http://localhost:${port}/wp-login.php" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

log_info "[wordpress/healthcheck] Checking WordPress HTTP response..."
retry_with_timeout 120 10 _wp_responds
log_info "[wordpress/healthcheck] WordPress is responding on HTTP."

# --- Check 3: PVCs are bound ---
log_info "[wordpress/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[wordpress/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[wordpress/healthcheck] All PVCs are Bound."
else
    log_warn "[wordpress/healthcheck] Not all PVCs are Bound."
    exit 1
fi
