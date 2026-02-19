#!/usr/bin/env bash
# healthcheck.sh — ownCloud-specific health checks.
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

local_namespace="${HELM_NAMESPACE_PREFIX}owncloud"

# --- Check 1: MariaDB accepts connections ---
_mariadb_responds() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=owncloud,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        healthcheck.sh --connect 2>/dev/null
}

log_info "[owncloud/healthcheck] Checking MariaDB connectivity..."
retry_with_timeout 120 10 _mariadb_responds
log_info "[owncloud/healthcheck] MariaDB is accepting connections."

# --- Check 2: ownCloud status.php ---
_owncloud_responds() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=owncloud,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    local output
    output="$(kubectl exec -n "${local_namespace}" "$pod" -- \
        curl -sS --max-time 10 "http://localhost:8080/status.php" 2>/dev/null || true)"
    echo "$output" | grep -q '"installed"'
}

log_info "[owncloud/healthcheck] Checking ownCloud status..."
retry_with_timeout 120 10 _owncloud_responds
log_info "[owncloud/healthcheck] ownCloud is installed and responding."

# --- Check 3: PVCs are bound ---
log_info "[owncloud/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[owncloud/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[owncloud/healthcheck] All PVCs are Bound."
else
    log_warn "[owncloud/healthcheck] Not all PVCs are Bound."
    exit 1
fi
