#!/usr/bin/env bash
# healthcheck.sh — Kafka-specific health check.
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

check_kafka_ready() {
    local namespace="${HELM_NAMESPACE_PREFIX}kafka"
    log_info "[kafka/healthcheck] Checking Kafka health..."

    retry_with_timeout 180 10 _kafka_responds "$namespace"

    log_info "[kafka/healthcheck] Kafka is healthy."
}

_kafka_responds() {
    local namespace="$1"
    local pod
    pod="$(kubectl get pods -n "$namespace" \
        -l app.kubernetes.io/component=controller \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"

    [[ -n "$pod" ]] || return 1

    local phase
    phase="$(kubectl get pod -n "$namespace" "$pod" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"

    [[ "$phase" == "Running" ]]
}

check_kafka_ready
