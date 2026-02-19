#!/usr/bin/env bash
# post-install.sh — Jenkins post-install hook.
# Waits for the Jenkins pod to be ready, reads the initial admin password, and logs access info.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}jenkins"

log_info "[jenkins/post-install] Waiting for Jenkins to be ready..."

# --- Wait for Jenkins pod to be ready ---
_get_jenkins_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=jenkins,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_jenkins_pod_ready() {
    local pod
    pod="$(_get_jenkins_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _jenkins_pod_ready

jenkins_pod="$(_get_jenkins_pod)"
log_info "[jenkins/post-install] Jenkins pod ready: ${jenkins_pod}"

# --- Read initial admin password ---
_read_admin_password() {
    kubectl exec -n "${local_namespace}" "${jenkins_pod}" -- \
        cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null
}

log_info "[jenkins/post-install] Waiting for initial admin password..."
initial_password=""
if retry_with_timeout 120 10 _read_admin_password; then
    initial_password="$(_read_admin_password)"
    log_info "[jenkins/post-install] Initial admin password: ${initial_password}"
else
    log_warn "[jenkins/post-install] Could not read initial admin password (may already be configured)."
fi

# --- Log access info ---
local_http_port="${PARAM_JENKINS_HTTP_NODEPORT:-30080}"
local_agent_port="${PARAM_JENKINS_AGENT_NODEPORT:-30500}"
log_info "[jenkins/post-install] Jenkins UI: http://<VM-IP>:${local_http_port}"
log_info "[jenkins/post-install] Agent port: ${local_agent_port}"
log_info "[jenkins/post-install] Complete the setup wizard by visiting the URL above."
