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
        bash "$installer" $K3S_INSTALL_FLAGS \
        --cluster-cidr="10.42.0.0/16,fd42::/56" \
        --service-cidr="10.43.0.0/16,fd43::/112"
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
    setup_ipv6_forwarding

    log_info "K3s cluster is ready."
}

# setup_ipv6_forwarding — Ensure IPv6 traffic on ports 80/443 reaches Traefik.
# In dual-stack K3s, klipper-lb handles this, but we add explicit ip6tables rules
# as a safety net for cases where the LoadBalancer IPv6 binding lags.
setup_ipv6_forwarding() {
    # Only run if the host has a global IPv6 address
    local ipv6
    ipv6="$(ip -6 addr show scope global 2>/dev/null \
             | grep -oP '(?<=inet6 )[0-9a-fA-F:]+(?=/)' \
             | grep -iv '^fe80' | head -1 || true)"
    [[ -z "$ipv6" ]] && return 0

    log_info "Setting up IPv6 port forwarding for Traefik (host: ${ipv6})..."

    # Wait up to 60s for Traefik NodePorts to be assigned
    local http_port https_port deadline
    deadline=$((SECONDS + 60))
    while [[ $SECONDS -lt $deadline ]]; do
        http_port="$(kubectl get svc traefik -n kube-system \
            -o jsonpath='{.spec.ports[?(@.name=="web")].nodePort}' 2>/dev/null || true)"
        https_port="$(kubectl get svc traefik -n kube-system \
            -o jsonpath='{.spec.ports[?(@.name=="websecure")].nodePort}' 2>/dev/null || true)"
        [[ -n "$http_port" && -n "$https_port" ]] && break
        sleep 5
    done

    if [[ -z "$http_port" || -z "$https_port" ]]; then
        log_warn "Could not detect Traefik NodePorts — skipping IPv6 forwarding rules."
        return 0
    fi

    log_info "Traefik NodePorts: HTTP=${http_port}, HTTPS=${https_port}"

    # Add ip6tables rules (idempotent: check before adding)
    ip6tables -t nat -C PREROUTING -i ens3 -p tcp --dport 80 -j REDIRECT --to-port "$http_port" 2>/dev/null \
        || ip6tables -t nat -A PREROUTING -i ens3 -p tcp --dport 80 -j REDIRECT --to-port "$http_port"
    ip6tables -t nat -C PREROUTING -i ens3 -p tcp --dport 443 -j REDIRECT --to-port "$https_port" 2>/dev/null \
        || ip6tables -t nat -A PREROUTING -i ens3 -p tcp --dport 443 -j REDIRECT --to-port "$https_port"

    # Persist rules across reboots
    if command -v ip6tables-save &>/dev/null; then
        mkdir -p /etc/iptables
        ip6tables-save > /etc/iptables/rules.v6
        # Restore on boot if netfilter-persistent is available
        if systemctl list-unit-files netfilter-persistent.service &>/dev/null; then
            systemctl enable netfilter-persistent 2>/dev/null || true
        fi
    fi

    log_info "IPv6 port forwarding rules applied."
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
