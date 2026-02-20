#!/usr/bin/env bash
# post-install.sh — NATS JetStream post-install hook.
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

local_namespace="${HELM_NAMESPACE_PREFIX}nats-jetstream"

log_info "[nats-jetstream/post-install] Waiting for NATS JetStream to be ready..."

# --- Wait for NATS pod to be ready ---
_get_nats_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=nats-jetstream,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_nats_pod_ready() {
    local pod
    pod="$(_get_nats_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _nats_pod_ready

nats_pod="$(_get_nats_pod)"
log_info "[nats-jetstream/post-install] NATS JetStream pod ready: ${nats_pod}"

# --- Log connection info ---
client_port="${PARAM_NATS_CLIENT_NODEPORT:-30422}"
monitoring_port="${PARAM_NATS_MONITORING_NODEPORT:-30822}"
log_info "[nats-jetstream/post-install] NATS client: nats://<VM-IP>:${client_port}"
log_info "[nats-jetstream/post-install] Monitoring: http://<VM-IP>:${monitoring_port}"
