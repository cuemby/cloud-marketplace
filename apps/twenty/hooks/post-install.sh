#!/usr/bin/env bash
# post-install.sh — Twenty CRM post-install hook.
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

local_namespace="${HELM_NAMESPACE_PREFIX}twenty"

log_info "[twenty/post-install] Waiting for Twenty CRM to be ready..."

# --- Wait for Twenty pod to be ready ---
_get_twenty_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=twenty,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_twenty_pod_ready() {
    local pod
    pod="$(_get_twenty_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _twenty_pod_ready

twenty_pod="$(_get_twenty_pod)"
log_info "[twenty/post-install] Twenty CRM pod ready: ${twenty_pod}"

# --- Log connection info ---
http_port="${PARAM_HTTP_NODEPORT:-30080}"
log_info "[twenty/post-install] Twenty CRM: http://<VM-IP>:${http_port}"
