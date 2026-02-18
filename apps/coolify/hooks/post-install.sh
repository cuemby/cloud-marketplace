#!/usr/bin/env bash
# post-install.sh — Coolify post-install hook.
# Waits for the Coolify pod to be ready and logs access information.
# Admin account is created interactively via Coolify's first-visit registration UI.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}coolify"

log_info "[coolify/post-install] Waiting for Coolify to be ready..."

# --- Wait for Coolify pod to be ready ---
_get_coolify_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=coolify,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_coolify_pod_ready() {
    local pod
    pod="$(_get_coolify_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _coolify_pod_ready

coolify_pod="$(_get_coolify_pod)"
log_info "[coolify/post-install] Coolify pod ready: ${coolify_pod}"

# --- Log access info ---
local_port="${PARAM_COOLIFY_NODEPORT:-30800}"
log_info "[coolify/post-install] Coolify UI: http://<VM-IP>:${local_port}"
log_info "[coolify/post-install] Create your admin account by visiting the URL above."
log_info "[coolify/post-install] Deployed apps will be accessible on ports 80 (HTTP) and 443 (HTTPS)."
