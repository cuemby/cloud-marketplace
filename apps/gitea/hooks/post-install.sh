#!/usr/bin/env bash
# post-install.sh — Gitea post-install hook.
# Waits for the Gitea pod to be ready and logs access information.
# Admin account is created interactively via Gitea's first-visit install wizard.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}gitea"

log_info "[gitea/post-install] Waiting for Gitea to be ready..."

# --- Wait for Gitea pod to be ready ---
_get_gitea_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=gitea,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_gitea_pod_ready() {
    local pod
    pod="$(_get_gitea_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _gitea_pod_ready

gitea_pod="$(_get_gitea_pod)"
log_info "[gitea/post-install] Gitea pod ready: ${gitea_pod}"

# --- Log access info ---
local_http_port="${PARAM_GITEA_HTTP_NODEPORT:-30300}"
local_ssh_port="${PARAM_GITEA_SSH_NODEPORT:-30022}"
log_info "[gitea/post-install] Gitea Web UI: http://<VM-IP>:${local_http_port}"
log_info "[gitea/post-install] Git SSH: ssh://git@<VM-IP>:${local_ssh_port}"
log_info "[gitea/post-install] Create your admin account by visiting the URL above."
