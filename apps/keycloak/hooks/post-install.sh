#!/usr/bin/env bash
# post-install.sh — Keycloak post-install hook.
# Waits for the Keycloak pod to be ready and logs access information.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}keycloak"

log_info "[keycloak/post-install] Waiting for Keycloak to be ready..."

# --- Wait for Keycloak pod to be ready ---
_get_keycloak_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=keycloak,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_keycloak_pod_ready() {
    local pod
    pod="$(_get_keycloak_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _keycloak_pod_ready

keycloak_pod="$(_get_keycloak_pod)"
log_info "[keycloak/post-install] Keycloak pod ready: ${keycloak_pod}"

# --- Log access info ---
local_port="${PARAM_KEYCLOAK_NODEPORT:-30808}"
log_info "[keycloak/post-install] Keycloak UI: http://<VM-IP>:${local_port}"
log_info "[keycloak/post-install] Admin Console: http://<VM-IP>:${local_port}/admin"
log_info "[keycloak/post-install] Admin user: ${PARAM_KEYCLOAK_ADMIN_USER:-admin}"
