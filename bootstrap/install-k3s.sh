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

    # Download installer to a temp file so we can detect download failures
    local installer
    installer="$(mktemp /tmp/k3s-install-XXXXXX.sh)"
    log_info "Downloading K3s installer..."
    if ! curl -fL --retry 3 --retry-delay 5 -o "$installer" https://get.k3s.io; then
        rm -f "$installer"
        log_fatal "Failed to download K3s installer from https://get.k3s.io"
    fi

    # Copy Traefik Gateway API config (must exist before K3s starts)
    local manifests_dir="/var/lib/rancher/k3s/server/manifests"
    mkdir -p "$manifests_dir"
    cp "${SCRIPT_DIR}/manifests/traefik-config.yaml" "$manifests_dir/"
    log_info "Traefik Gateway API config installed."

    log_info "Running K3s installer..."
    # shellcheck disable=SC2086
    INSTALL_K3S_CHANNEL="$channel" \
        bash "$installer" $K3S_INSTALL_FLAGS
    rm -f "$installer"

    # Verify the service was actually created
    if ! systemctl list-unit-files k3s.service &>/dev/null; then
        log_fatal "K3s installation completed but k3s.service not found"
    fi

    log_info "K3s installed, waiting for cluster readiness..."

    export KUBECONFIG="$KUBECONFIG_PATH"

    wait_for_k3s_node
    wait_for_coredns
    wait_for_traefik

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

wait_for_traefik() {
    log_info "Waiting for Traefik to be Running..."
    retry_with_timeout "$TIMEOUT_K3S" "$RETRY_INTERVAL" _traefik_is_running
}

_traefik_is_running() {
    local phase
    phase="$(kubectl get pods -n kube-system \
        -l app.kubernetes.io/name=traefik \
        -o jsonpath='{.items[0].status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_k3s
fi
