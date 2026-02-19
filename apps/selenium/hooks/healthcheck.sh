#!/usr/bin/env bash
# healthcheck.sh — Selenium Grid health checks.
# Called by the generic healthcheck after pod/service checks pass.
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

# --- Check 1: Hub is ready and accepting sessions ---
_hub_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=selenium,app.kubernetes.io/component=hub \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        curl -sf http://localhost:4444/wd/hub/status 2>/dev/null | grep -q '"ready":\s*true'
}

log_info "[selenium/healthcheck] Checking Hub status..."
retry_with_timeout 120 10 _hub_ready
log_info "[selenium/healthcheck] Selenium Hub is ready."

# --- Check 2: Chrome node is registered ---
_chrome_node_running() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=selenium,app.kubernetes.io/component=node-chrome \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

log_info "[selenium/healthcheck] Checking Chrome node..."
retry_with_timeout 120 10 _chrome_node_running
log_info "[selenium/healthcheck] Chrome node is running."

# --- Check 3: Firefox node is registered ---
_firefox_node_running() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=selenium,app.kubernetes.io/component=node-firefox \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

log_info "[selenium/healthcheck] Checking Firefox node..."
retry_with_timeout 120 10 _firefox_node_running
log_info "[selenium/healthcheck] Firefox node is running."
