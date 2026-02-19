#!/usr/bin/env bash
# post-install.sh — SonarQube post-install hook.
# Waits for the SonarQube pod to be ready and logs access information.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}sonarqube"

log_info "[sonarqube/post-install] Waiting for SonarQube to be ready..."

# --- Wait for SonarQube pod to be ready ---
_get_sonarqube_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=sonarqube,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_sonarqube_pod_ready() {
    local pod
    pod="$(_get_sonarqube_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 600 10 _sonarqube_pod_ready

sonarqube_pod="$(_get_sonarqube_pod)"
log_info "[sonarqube/post-install] SonarQube pod ready: ${sonarqube_pod}"

# --- Log access info ---
local_port="${PARAM_SONARQUBE_NODEPORT:-30900}"
log_info "[sonarqube/post-install] SonarQube web UI: http://<VM-IP>:${local_port}"
log_info "[sonarqube/post-install] Default login: admin / admin (change on first login)"
