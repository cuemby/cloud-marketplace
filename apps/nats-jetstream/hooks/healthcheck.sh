#!/usr/bin/env bash
# healthcheck.sh — NATS JetStream health checks.
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

local_namespace="${HELM_NAMESPACE_PREFIX}nats-jetstream"

# --- Check 1: NATS is responding ---
_nats_is_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=nats-jetstream,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        wget -q --spider http://127.0.0.1:8222/healthz 2>/dev/null
}

log_info "[nats-jetstream/healthcheck] Checking NATS connectivity..."
retry_with_timeout 120 10 _nats_is_ready
log_info "[nats-jetstream/healthcheck] NATS is responding."

# --- Check 2: JetStream is enabled ---
_jetstream_enabled() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=nats-jetstream,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        wget -qO- http://127.0.0.1:8222/jsz 2>/dev/null | grep -q '"streams"'
}

log_info "[nats-jetstream/healthcheck] Verifying JetStream is enabled..."
retry_with_timeout 120 10 _jetstream_enabled
log_info "[nats-jetstream/healthcheck] JetStream is enabled."

# --- Check 3: PVCs are bound ---
log_info "[nats-jetstream/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[nats-jetstream/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[nats-jetstream/healthcheck] All PVCs are Bound."
else
    log_warn "[nats-jetstream/healthcheck] Not all PVCs are Bound."
    exit 1
fi
