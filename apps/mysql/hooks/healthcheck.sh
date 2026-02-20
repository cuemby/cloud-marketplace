#!/usr/bin/env bash
# healthcheck.sh — MySQL-specific health checks.
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

local_namespace="${HELM_NAMESPACE_PREFIX}mysql"

# --- Check 1: MySQL accepts connections ---
_mysql_is_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=mysql,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        mysqladmin ping -h 127.0.0.1 2>/dev/null
}

log_info "[mysql/healthcheck] Checking MySQL connectivity..."
retry_with_timeout 120 10 _mysql_is_ready
log_info "[mysql/healthcheck] MySQL is accepting connections."

# --- Check 2: Authenticated status check ---
_mysql_status_ok() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=mysql,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        /bin/sh -c 'mysqladmin -u root -p"${MYSQL_ROOT_PASSWORD}" status 2>/dev/null' \
        | grep -q "Uptime"
}

_mysql_debug_auth() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=mysql,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    log_warn "[mysql/healthcheck] Debug — checking env vars in container:"
    kubectl exec -n "${local_namespace}" "$pod" -- \
        /bin/sh -c 'echo "MYSQL_ROOT_PASSWORD set: ${MYSQL_ROOT_PASSWORD:+yes}"; echo "length: ${#MYSQL_ROOT_PASSWORD}"' 2>&1 || true
    log_warn "[mysql/healthcheck] Debug — mysqladmin status output:"
    kubectl exec -n "${local_namespace}" "$pod" -- \
        /bin/sh -c 'mysqladmin -u root -p"${MYSQL_ROOT_PASSWORD}" status 2>&1; echo "EXIT_CODE=$?"' 2>&1 || true
    log_warn "[mysql/healthcheck] Debug — mysqladmin ping with auth:"
    kubectl exec -n "${local_namespace}" "$pod" -- \
        /bin/sh -c 'mysqladmin -u root -p"${MYSQL_ROOT_PASSWORD}" ping 2>&1; echo "EXIT_CODE=$?"' 2>&1 || true
}

log_info "[mysql/healthcheck] Verifying MySQL authenticated status..."
if ! retry_with_timeout 30 10 _mysql_status_ok; then
    _mysql_debug_auth
    log_error "[mysql/healthcheck] Authenticated status check failed."
    exit 1
fi
log_info "[mysql/healthcheck] MySQL authenticated status verified."

# --- Check 3: PVCs are bound ---
log_info "[mysql/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[mysql/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[mysql/healthcheck] All PVCs are Bound."
else
    log_warn "[mysql/healthcheck] Not all PVCs are Bound."
    exit 1
fi
