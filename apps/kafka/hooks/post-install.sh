#!/usr/bin/env bash
# post-install.sh — Kafka post-install hook.
# Waits for the Kafka pod to be ready and logs access information.
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

log_info "[kafka/post-install] Waiting for Kafka to be ready..."

# --- Wait for Kafka pod to be ready ---
_get_kafka_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=kafka,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_kafka_pod_ready() {
    local pod
    pod="$(_get_kafka_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 600 10 _kafka_pod_ready

kafka_pod="$(_get_kafka_pod)"
log_info "[kafka/post-install] Kafka pod ready: ${kafka_pod}"

# --- Log access info ---
local_port="${PARAM_KAFKA_NODEPORT:-30909}"
log_info "[kafka/post-install] Kafka broker: <VM-IP>:${local_port}"
log_info "[kafka/post-install] Bootstrap servers: <VM-IP>:${local_port}"
log_info "[kafka/post-install] KRaft mode (no ZooKeeper). Security disabled — use network isolation."
