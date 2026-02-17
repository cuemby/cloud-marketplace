#!/usr/bin/env bash
# install-helm.sh — Install Helm binary.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/constants.sh
source "${SCRIPT_DIR}/lib/constants.sh"
# shellcheck source=lib/logging.sh
source "${SCRIPT_DIR}/lib/logging.sh"

install_helm() {
    local version="${HELM_VERSION:-$DEFAULT_HELM_VERSION}"

    log_section "Installing Helm (version: ${version})"

    if command -v helm &>/dev/null; then
        local current
        current="$(helm version --short 2>/dev/null | cut -d'+' -f1)"
        log_info "Helm already installed: ${current}"
        return 0
    fi

    curl -sfL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | \
        DESIRED_VERSION="$version" bash

    if ! command -v helm &>/dev/null; then
        log_fatal "Helm installation failed — binary not found in PATH"
    fi

    log_info "Helm installed: $(helm version --short)"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_helm
fi
