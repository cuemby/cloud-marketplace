#!/usr/bin/env bash
# post-install.sh — Nextcloud post-install hook.
# Waits for the Nextcloud pod to be ready and logs access information.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}nextcloud"

log_info "[nextcloud/post-install] Waiting for Nextcloud to be ready..."

# --- Wait for Nextcloud pod to be ready ---
_get_nc_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=nextcloud,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_nc_pod_ready() {
    local pod
    pod="$(_get_nc_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 600 10 _nc_pod_ready

nc_pod="$(_get_nc_pod)"
log_info "[nextcloud/post-install] Nextcloud pod ready: ${nc_pod}"

# --- Log access info ---
local_port="${PARAM_HTTP_NODEPORT:-${DEFAULT_HTTP_NODEPORT}}"
log_info "[nextcloud/post-install] Web UI: http://<VM-IP>:${local_port}"
log_info "[nextcloud/post-install] Status: http://<VM-IP>:${local_port}/status.php"
log_info "[nextcloud/post-install] Username: ${PARAM_NEXTCLOUD_ADMIN_USER:-admin}"
