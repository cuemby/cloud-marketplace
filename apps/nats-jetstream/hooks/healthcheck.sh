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

# Note: The NATS Docker image is scratch-based (no shell, no wget/curl).
# K8s httpGet probes handle in-container health checks. For hook checks,
# we query the monitoring endpoint via the ClusterIP service from the host.

# --- Check 1: NATS pod is Ready (K8s probes verify /healthz) ---
_nats_is_ready() {
    local ready
    ready="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=nats-jetstream,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)"
    [[ "$ready" == "True" ]]
}

log_info "[nats-jetstream/healthcheck] Checking NATS pod readiness..."
retry_with_timeout 120 10 _nats_is_ready
log_info "[nats-jetstream/healthcheck] NATS pod is Ready."

# --- Check 2: JetStream is enabled (query via K8s API proxy) ---
_jetstream_enabled() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=nats-jetstream,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl get --raw \
        "/api/v1/namespaces/${local_namespace}/pods/${pod}:8222/proxy/jsz" \
        2>/dev/null | grep -q '"streams"'
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
