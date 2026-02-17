#!/usr/bin/env bash
# install-k3s.sh — Install K3s and wait for cluster readiness.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/constants.sh
source "${SCRIPT_DIR}/lib/constants.sh"
# shellcheck source=lib/logging.sh
source "${SCRIPT_DIR}/lib/logging.sh"
# shellcheck source=lib/retry.sh
source "${SCRIPT_DIR}/lib/retry.sh"

install_k3s() {
    local channel="${K3S_CHANNEL:-$DEFAULT_K3S_CHANNEL}"

    log_section "Installing K3s (channel: ${channel})"

    # shellcheck disable=SC2086
    curl -sfL https://get.k3s.io | \
        INSTALL_K3S_CHANNEL="$channel" \
        sh -s - $K3S_INSTALL_FLAGS

    log_info "K3s binary installed, waiting for cluster readiness..."

    export KUBECONFIG="$KUBECONFIG_PATH"

    wait_for_k3s_node
    wait_for_coredns

    log_info "K3s cluster is ready."
}

wait_for_k3s_node() {
    log_info "Waiting for K3s node to be Ready (timeout: ${TIMEOUT_K3S}s)..."
    retry_with_timeout "$TIMEOUT_K3S" "$RETRY_INTERVAL" _node_is_ready
}

_node_is_ready() {
    local status
    status="$(kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)"
    [[ "$status" == "True" ]]
}

wait_for_coredns() {
    log_info "Waiting for CoreDNS to be Running..."
    retry_with_timeout "$TIMEOUT_K3S" "$RETRY_INTERVAL" _coredns_is_running
}

_coredns_is_running() {
    local running
    running="$(kubectl get pods -n kube-system -l k8s-app=kube-dns \
        -o jsonpath='{.items[0].status.phase}' 2>/dev/null)"
    [[ "$running" == "Running" ]]
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_k3s
fi
