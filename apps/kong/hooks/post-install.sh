#!/usr/bin/env bash
# post-install.sh — Kong Gateway post-install hook.
# Waits for the Kong migrations job to complete and the gateway pod to be ready.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}kong"

# --- Wait for migrations job to complete ---
log_info "[kong/post-install] Waiting for Kong migrations job to complete..."

_migrations_complete() {
    local status
    status="$(kubectl get job kong-migrations -n "${local_namespace}" \
        -o jsonpath='{.status.succeeded}' 2>/dev/null)"
    [[ "$status" == "1" ]]
}

retry_with_timeout 300 10 _migrations_complete
log_info "[kong/post-install] Kong migrations completed successfully."

# --- Wait for Kong pod to be ready ---
log_info "[kong/post-install] Waiting for Kong Gateway to be ready..."

_get_kong_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=kong,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_kong_pod_ready() {
    local pod
    pod="$(_get_kong_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _kong_pod_ready

kong_pod="$(_get_kong_pod)"
log_info "[kong/post-install] Kong Gateway pod ready: ${kong_pod}"

# --- Log access info ---
proxy_port="${PARAM_KONG_PROXY_NODEPORT:-30800}"
admin_port="${PARAM_KONG_ADMIN_NODEPORT:-30801}"
log_info "[kong/post-install] Kong Proxy: http://<VM-IP>:${proxy_port}"
log_info "[kong/post-install] Kong Admin API: http://<VM-IP>:${admin_port}"
log_info "[kong/post-install] Status: curl http://<VM-IP>:${admin_port}/status"
