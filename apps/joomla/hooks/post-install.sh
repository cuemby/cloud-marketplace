#!/usr/bin/env bash
# post-install.sh — Joomla post-install hook.
# Waits for the Joomla pod to be ready and logs access information.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}joomla"

log_info "[joomla/post-install] Waiting for Joomla to be ready..."

# --- Wait for Joomla pod to be ready ---
_get_joomla_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=joomla,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_joomla_pod_ready() {
    local pod
    pod="$(_get_joomla_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _joomla_pod_ready

joomla_pod="$(_get_joomla_pod)"
log_info "[joomla/post-install] Joomla pod ready: ${joomla_pod}"

# --- Log access info ---
local_port="${PARAM_HTTP_NODEPORT:-${DEFAULT_HTTP_NODEPORT}}"
log_info "[joomla/post-install] Site: http://<VM-IP>:${local_port}"
log_info "[joomla/post-install] Admin: http://<VM-IP>:${local_port}/administrator/"
log_info "[joomla/post-install] Complete the installation wizard on first visit."
