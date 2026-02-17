#!/usr/bin/env bash
# entrypoint.sh — Main bootstrap orchestrator.
# Called by cloud-init user-data to set up K3s + Helm + deploy an application.
#
# Required env vars:
#   APP_NAME     — application to deploy (e.g., "wordpress")
#   APP_VERSION  — (optional) version to deploy
#   PARAM_*      — app-specific parameters mapped to Helm values
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared libraries
# shellcheck source=lib/constants.sh
source "${SCRIPT_DIR}/lib/constants.sh"
# shellcheck source=lib/logging.sh
source "${SCRIPT_DIR}/lib/logging.sh"
# shellcheck source=lib/validation.sh
source "${SCRIPT_DIR}/lib/validation.sh"
# shellcheck source=lib/retry.sh
source "${SCRIPT_DIR}/lib/retry.sh"
# shellcheck source=lib/network.sh
source "${SCRIPT_DIR}/lib/network.sh"
# shellcheck source=lib/cleanup.sh
source "${SCRIPT_DIR}/lib/cleanup.sh"

# Set up traps
trap 'on_error $LINENO' ERR
trap 'on_exit' EXIT

# Ensure log directory exists
mkdir -p "$LOG_DIR"
mkdir -p "$STATE_DIR"

main() {
    log_section "Cuemby Cloud Marketplace Bootstrap"
    log_info "App: ${APP_NAME:-<not set>}"
    log_info "Version: ${APP_VERSION:-<default>}"

    # Phase 1: Validate inputs
    write_state "$STATE_VALIDATING"
    log_section "Phase 1: Validating inputs"
    validate_required_env APP_NAME
    validate_app_exists "$APP_NAME"
    validate_app_version "$APP_NAME" "${APP_VERSION:-}"
    validate_parameters "$APP_NAME"
    log_info "Input validation passed."

    # Phase 2: System preparation
    write_state "$STATE_PREPARING"
    log_section "Phase 2: Preparing system"
    wait_for_network
    ensure_dependencies
    log_info "System preparation complete."

    # Phase 3: Install K3s
    write_state "$STATE_INSTALLING_K3S"
    log_section "Phase 3: Installing K3s"
    source "${SCRIPT_DIR}/install-k3s.sh"
    install_k3s
    export KUBECONFIG="$KUBECONFIG_PATH"

    # Phase 4: Install Helm
    write_state "$STATE_INSTALLING_HELM"
    log_section "Phase 4: Installing Helm"
    source "${SCRIPT_DIR}/install-helm.sh"
    install_helm

    # Phase 5: Deploy application
    write_state "$STATE_DEPLOYING"
    log_section "Phase 5: Deploying ${APP_NAME}"
    "${SCRIPT_DIR}/deploy-app.sh"

    # Phase 6: Health check
    write_state "$STATE_HEALTHCHECK"
    log_section "Phase 6: Running health checks"
    "${SCRIPT_DIR}/healthcheck.sh"

    # Done
    write_state "$STATE_READY"
    log_section "Bootstrap complete — ${APP_NAME} is ready"
}

main "$@"
