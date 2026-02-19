#!/usr/bin/env bash
# post-install.sh — Selenium Grid post-install hook.
# Waits for Hub and browser nodes to register, logs access info.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}selenium"

# --- Wait for Hub pod to be ready ---
log_info "[selenium/post-install] Waiting for Selenium Hub to be ready..."

_get_hub_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=selenium,app.kubernetes.io/component=hub \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_hub_pod_ready() {
    local pod
    pod="$(_get_hub_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _hub_pod_ready

hub_pod="$(_get_hub_pod)"
log_info "[selenium/post-install] Selenium Hub pod ready: ${hub_pod}"

# --- Wait for Grid to report ready ---
log_info "[selenium/post-install] Waiting for Grid to report ready status..."

_grid_ready() {
    local pod
    pod="$(_get_hub_pod)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        curl -sf http://localhost:4444/wd/hub/status 2>/dev/null | grep -q '"ready":\s*true'
}

retry_with_timeout 180 10 _grid_ready
log_info "[selenium/post-install] Selenium Grid is ready."

# --- Log access info ---
hub_port="${PARAM_SELENIUM_HUB_NODEPORT:-30444}"
log_info "[selenium/post-install] Grid UI: http://<VM-IP>:${hub_port}/ui"
log_info "[selenium/post-install] Grid Status: http://<VM-IP>:${hub_port}/wd/hub/status"
log_info "[selenium/post-install] WebDriver: http://<VM-IP>:${hub_port}/wd/hub"
