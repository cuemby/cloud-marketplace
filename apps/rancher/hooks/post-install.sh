#!/usr/bin/env bash
# post-install.sh — Rancher post-install hook.
# Waits for the Rancher pod to be ready and logs bootstrap credentials.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}rancher"

# --- Wait for Rancher pod to be ready ---
log_info "[rancher/post-install] Waiting for Rancher to be ready..."

_get_rancher_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=rancher,app.kubernetes.io/component=rancher \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_rancher_pod_ready() {
    local pod
    pod="$(_get_rancher_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 600 15 _rancher_pod_ready

rancher_pod="$(_get_rancher_pod)"
log_info "[rancher/post-install] Rancher pod ready: ${rancher_pod}"

# --- Log access info ---
https_port="${PARAM_RANCHER_HTTPS_NODEPORT:-30443}"
log_info "[rancher/post-install] Web UI: https://<VM-IP>:${https_port}"
log_info "[rancher/post-install] Bootstrap password: ${PARAM_RANCHER_BOOTSTRAP_PASSWORD:-<check secret>}"
log_info "[rancher/post-install] Login with 'admin' user and the bootstrap password above."
log_info "[rancher/post-install] You will be prompted to change the password on first login."
