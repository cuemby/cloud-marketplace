#!/usr/bin/env bash
# healthcheck.sh — FerretDB-specific health checks.
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

local_namespace="${HELM_NAMESPACE_PREFIX}ferretdb"

# --- Check 1: PostgreSQL accepts connections ---
_pg_is_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=ferretdb,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        pg_isready -U ferretdb 2>/dev/null
}

log_info "[ferretdb/healthcheck] Checking PostgreSQL connectivity..."
retry_with_timeout 120 10 _pg_is_ready
log_info "[ferretdb/healthcheck] PostgreSQL is accepting connections."

# --- Check 2: FerretDB pod is Ready (scratch image — cannot exec into it) ---
# Kubernetes TCP probe on port 27017 verifies FerretDB is accepting connections.
_ferretdb_is_ready() {
    local ready
    ready="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=ferretdb,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)"
    [[ "$ready" == "True" ]]
}

log_info "[ferretdb/healthcheck] Checking FerretDB connectivity..."
retry_with_timeout 120 10 _ferretdb_is_ready
log_info "[ferretdb/healthcheck] FerretDB is accepting connections."

# --- Check 3: PVCs are bound ---
log_info "[ferretdb/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[ferretdb/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[ferretdb/healthcheck] All PVCs are Bound."
else
    log_warn "[ferretdb/healthcheck] Not all PVCs are Bound."
    exit 1
fi
