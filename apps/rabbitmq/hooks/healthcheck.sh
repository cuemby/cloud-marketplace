#!/usr/bin/env bash
# healthcheck.sh — RabbitMQ-specific health checks.
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

local_namespace="${HELM_NAMESPACE_PREFIX}rabbitmq"

# --- Check 1: RabbitMQ node is running ---
_rabbitmq_is_running() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=rabbitmq,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        rabbitmq-diagnostics -q check_running 2>/dev/null
}

log_info "[rabbitmq/healthcheck] Checking RabbitMQ node status..."
retry_with_timeout 120 10 _rabbitmq_is_running
log_info "[rabbitmq/healthcheck] RabbitMQ node is running."

# --- Check 2: Broker functionality ---
_rabbitmq_broker_works() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=rabbitmq,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        rabbitmqctl list_queues 2>/dev/null
}

log_info "[rabbitmq/healthcheck] Verifying broker functionality..."
retry_with_timeout 120 10 _rabbitmq_broker_works
log_info "[rabbitmq/healthcheck] RabbitMQ broker is functional."

# --- Check 3: PVCs are bound ---
log_info "[rabbitmq/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[rabbitmq/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[rabbitmq/healthcheck] All PVCs are Bound."
else
    log_warn "[rabbitmq/healthcheck] Not all PVCs are Bound."
    exit 1
fi
