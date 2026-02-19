#!/usr/bin/env bash
# healthcheck.sh — Harbor-specific health checks.
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

local_namespace="${HELM_NAMESPACE_PREFIX}harbor"

# --- Check 1: Harbor DB accepts connections ---
_db_is_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=harbor,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        pg_isready -U harbor -d registry 2>/dev/null
}

log_info "[harbor/healthcheck] Checking Harbor DB connectivity..."
retry_with_timeout 120 10 _db_is_ready
log_info "[harbor/healthcheck] Harbor DB is accepting connections."

# --- Check 2: Harbor Core API responds ---
_core_api_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=harbor,app.kubernetes.io/component=core \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        curl -sf http://localhost:8080/api/v2.0/ping 2>/dev/null
}

log_info "[harbor/healthcheck] Checking Harbor Core API..."
retry_with_timeout 120 10 _core_api_ready
log_info "[harbor/healthcheck] Harbor Core API is responding."

# --- Check 3: Registry pod is fully ready (both registry + registryctl containers) ---
_registry_ready() {
    # registry-photon image lacks wget/curl; instead verify via K8s readiness conditions
    # The pod has HTTP readiness probes on both containers (5000 and 8080)
    local ready
    ready="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=harbor,app.kubernetes.io/component=registry \
        -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)"
    [[ "$ready" == "True" ]]
}

log_info "[harbor/healthcheck] Checking Harbor Registry readiness..."
retry_with_timeout 120 10 _registry_ready
log_info "[harbor/healthcheck] Harbor Registry pod is fully ready."

# --- Check 4: PVCs are bound ---
log_info "[harbor/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[harbor/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[harbor/healthcheck] All PVCs are Bound."
else
    log_warn "[harbor/healthcheck] Not all PVCs are Bound."
    exit 1
fi
