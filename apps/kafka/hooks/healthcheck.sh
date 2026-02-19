#!/usr/bin/env bash
# healthcheck.sh — Kafka-specific health checks.
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

local_namespace="${HELM_NAMESPACE_PREFIX}kafka"

# --- Check 1: Kafka broker is listening ---
_kafka_is_healthy() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=kafka,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    # Kafka has no HTTP health endpoint; check TCP connectivity on broker port
    kubectl exec -n "${local_namespace}" "$pod" -- \
        bash -c "echo > /dev/tcp/127.0.0.1/9092" 2>/dev/null
}

log_info "[kafka/healthcheck] Checking Kafka broker health..."
retry_with_timeout 120 10 _kafka_is_healthy
log_info "[kafka/healthcheck] Kafka broker is accepting connections."

# --- Check 2: PVCs are bound ---
log_info "[kafka/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[kafka/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[kafka/healthcheck] All PVCs are Bound."
else
    log_warn "[kafka/healthcheck] Not all PVCs are Bound."
    exit 1
fi
