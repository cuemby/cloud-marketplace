#!/usr/bin/env bash
# post-install.sh — Jenkins post-install hook.
# Waits for Jenkins pod to be ready and logs access info with credentials.
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

# --- Log access info ---
local_http_port="${PARAM_JENKINS_HTTP_NODEPORT:-30080}"
local_agent_port="${PARAM_JENKINS_AGENT_NODEPORT:-30500}"
log_info "[jenkins/post-install] Jenkins UI: http://<VM-IP>:${local_http_port}"
log_info "[jenkins/post-install] Agent port: ${local_agent_port}"
log_info "[jenkins/post-install] Username: admin"
log_info "[jenkins/post-install] Password: <see secret jenkins-admin-secret>"

if [[ "${PARAM_JENKINS_SSL_ENABLED:-}" == "true" ]]; then
    log_info "[jenkins/post-install] HTTPS: https://${PARAM_JENKINS_HOSTNAME:-}"
fi
