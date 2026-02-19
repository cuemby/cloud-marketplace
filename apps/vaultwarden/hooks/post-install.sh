#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

source "${BOOTSTRAP_DIR}/lib/logging.sh"
source "${BOOTSTRAP_DIR}/lib/constants.sh"
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}vaultwarden"

log_info "[vaultwarden/post-install] Waiting for Vaultwarden to be ready..."

_get_vaultwarden_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=vaultwarden,app.kubernetes.io/component=vaultwarden \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_vaultwarden_pod_ready() {
    local pod
    pod="$(_get_vaultwarden_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _vaultwarden_pod_ready

vaultwarden_pod="$(_get_vaultwarden_pod)"
log_info "[vaultwarden/post-install] Vaultwarden pod ready: ${vaultwarden_pod}"

local_port="${PARAM_VAULTWARDEN_NODEPORT:-30080}"
log_info "[vaultwarden/post-install] Web Vault: http://<VM-IP>:${local_port}"
log_info "[vaultwarden/post-install] Admin Panel: http://<VM-IP>:${local_port}/admin"
log_info "[vaultwarden/post-install] Use the configured admin token to access the admin panel."
