#!/usr/bin/env bash
# post-install.sh — ownCloud post-install hook.
# Waits for the ownCloud pod to be ready and logs access information.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}owncloud"

log_info "[owncloud/post-install] Waiting for ownCloud to be ready..."

# --- Wait for ownCloud pod to be ready ---
_get_oc_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=owncloud,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_oc_pod_ready() {
    local pod
    pod="$(_get_oc_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 600 10 _oc_pod_ready

oc_pod="$(_get_oc_pod)"
log_info "[owncloud/post-install] ownCloud pod ready: ${oc_pod}"

# --- Log access info ---
local_port="${PARAM_HTTP_NODEPORT:-${DEFAULT_HTTP_NODEPORT}}"
log_info "[owncloud/post-install] Web UI: http://<VM-IP>:${local_port}"
log_info "[owncloud/post-install] Status: http://<VM-IP>:${local_port}/status.php"
log_info "[owncloud/post-install] Username: ${PARAM_OWNCLOUD_ADMIN_USERNAME:-admin}"
