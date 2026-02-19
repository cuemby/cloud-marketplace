#!/usr/bin/env bash
# healthcheck.sh — MongoDB-specific health checks.
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

local_namespace="${HELM_NAMESPACE_PREFIX}mongodb"

# --- Check 1: MongoDB accepts connections ---
_mongodb_is_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=mongodb,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        mongosh --quiet --eval "db.adminCommand('ping')" \
        -u "${PARAM_MONGO_INITDB_ROOT_USERNAME}" \
        -p "${PARAM_MONGO_INITDB_ROOT_PASSWORD}" \
        --authenticationDatabase admin 2>/dev/null
}

log_info "[mongodb/healthcheck] Checking MongoDB connectivity..."
retry_with_timeout 120 10 _mongodb_is_ready
log_info "[mongodb/healthcheck] MongoDB is accepting connections."

# --- Check 2: Write operation succeeds ---
_mongodb_write_works() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=mongodb,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        mongosh --quiet --eval "db.getSiblingDB('test').healthcheck.insertOne({ts: new Date()})" \
        -u "${PARAM_MONGO_INITDB_ROOT_USERNAME}" \
        -p "${PARAM_MONGO_INITDB_ROOT_PASSWORD}" \
        --authenticationDatabase admin 2>/dev/null
}

log_info "[mongodb/healthcheck] Verifying MongoDB write operation..."
retry_with_timeout 120 10 _mongodb_write_works
log_info "[mongodb/healthcheck] MongoDB write operation verified."

# --- Check 3: PVCs are bound ---
log_info "[mongodb/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[mongodb/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[mongodb/healthcheck] All PVCs are Bound."
else
    log_warn "[mongodb/healthcheck] Not all PVCs are Bound."
    exit 1
fi
