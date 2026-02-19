#!/usr/bin/env bash
# post-install.sh — RabbitMQ post-install hook.
# Waits for the pod to be ready and logs connection info.
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

log_info "[rabbitmq/post-install] Waiting for RabbitMQ to be ready..."

# --- Wait for RabbitMQ pod to be ready ---
_get_rabbitmq_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=rabbitmq,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_rabbitmq_pod_ready() {
    local pod
    pod="$(_get_rabbitmq_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _rabbitmq_pod_ready

rabbitmq_pod="$(_get_rabbitmq_pod)"
log_info "[rabbitmq/post-install] RabbitMQ pod ready: ${rabbitmq_pod}"

# --- Log connection info ---
amqp_port="${PARAM_RABBITMQ_AMQP_NODEPORT:-30672}"
mgmt_port="${PARAM_RABBITMQ_MANAGEMENT_NODEPORT:-31672}"
log_info "[rabbitmq/post-install] AMQP: amqp://<VM-IP>:${amqp_port}"
log_info "[rabbitmq/post-install] Management UI: http://<VM-IP>:${mgmt_port}"
log_info "[rabbitmq/post-install] User: ${PARAM_RABBITMQ_DEFAULT_USER:-admin}"
