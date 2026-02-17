#!/usr/bin/env bash
# network.sh — Network readiness checks and dependency installation.
# Source this file; do not execute directly.

# Wait until the network is reachable (can resolve and reach an external host).
# Usage: wait_for_network [timeout_secs]
wait_for_network() {
    local timeout="${1:-$TIMEOUT_NETWORK}"
    log_info "Waiting for network connectivity (timeout: ${timeout}s)..."

    retry_with_timeout "$timeout" 5 _check_network

    log_info "Network is available."
}

_check_network() {
    curl -sf --max-time 5 -o /dev/null https://get.k3s.io
}

# Install required system dependencies if not already present.
# Supports apt and yum/dnf package managers.
# Usage: ensure_dependencies
ensure_dependencies() {
    local deps=(curl git jq)
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        log_debug "All system dependencies present"
    else
        log_info "Installing missing dependencies: ${missing[*]}"
        _install_packages "${missing[@]}"
    fi

    # yq is a standalone binary, install separately
    if ! command -v yq &>/dev/null; then
        _install_yq
    fi
}

_install_packages() {
    if command -v apt-get &>/dev/null; then
        apt-get update -qq
        apt-get install -y -qq "$@"
    elif command -v dnf &>/dev/null; then
        dnf install -y -q "$@"
    elif command -v yum &>/dev/null; then
        yum install -y -q "$@"
    else
        log_fatal "No supported package manager found (apt-get, dnf, yum)"
    fi
}

_install_yq() {
    log_info "Installing yq..."
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64)  arch="amd64" ;;
        aarch64) arch="arm64" ;;
        *)       log_fatal "Unsupported architecture: ${arch}" ;;
    esac

    local yq_url="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${arch}"
    curl -sfL "$yq_url" -o /usr/local/bin/yq
    chmod +x /usr/local/bin/yq
    log_info "yq installed: $(yq --version)"
}
