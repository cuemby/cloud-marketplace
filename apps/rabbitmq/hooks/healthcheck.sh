#!/usr/bin/env bash
# healthcheck.sh — RabbitMQ-specific health check.
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

check_rabbitmq_ping() {
    local namespace="${HELM_NAMESPACE_PREFIX}rabbitmq"
    log_info "[rabbitmq/healthcheck] Checking rabbitmq-diagnostics ping via kubectl exec..."

    retry_with_timeout 120 10 _rabbitmq_responds "$namespace"

    log_info "[rabbitmq/healthcheck] RabbitMQ is responding to ping."
}

_rabbitmq_responds() {
    local namespace="$1"
    local pod
    pod="$(kubectl get pods -n "$namespace" \
        -l app.kubernetes.io/component=rabbitmq \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"

    [[ -n "$pod" ]] || return 1

    kubectl exec -n "$namespace" "$pod" -- \
        rabbitmq-diagnostics -q ping 2>/dev/null || return 1
}

check_rabbitmq_ping
