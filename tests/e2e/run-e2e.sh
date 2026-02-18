#!/usr/bin/env bash
# run-e2e.sh — CI E2E test harness for a single app.
# Deploys an app on a pre-existing k3d cluster and runs health checks.
#
# Prerequisites: k3d cluster running, kubectl/helm/yq available.
#
# Usage: APP_NAME=redis ./tests/e2e/run-e2e.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ── Override paths for CI (not /opt/cuemby/marketplace) ──────────────────────

export MARKETPLACE_DIR="$REPO_DIR"
export APPS_DIR="${REPO_DIR}/apps"
export LOG_DIR="${REPO_DIR}/.e2e-logs"
export STATE_DIR="${REPO_DIR}/.e2e-state"
export KUBECONFIG_PATH="${KUBECONFIG:-${HOME}/.kube/config}"
export KUBECONFIG="$KUBECONFIG_PATH"
export CI_SKIP_SSL=true

# ── Source bootstrap libraries ───────────────────────────────────────────────

# shellcheck source=../../bootstrap/lib/constants.sh
source "${REPO_DIR}/bootstrap/lib/constants.sh"
# shellcheck source=../../bootstrap/lib/logging.sh
source "${REPO_DIR}/bootstrap/lib/logging.sh"
# shellcheck source=../../bootstrap/lib/validation.sh
source "${REPO_DIR}/bootstrap/lib/validation.sh"
# shellcheck source=../../bootstrap/lib/retry.sh
source "${REPO_DIR}/bootstrap/lib/retry.sh"
# shellcheck source=../../bootstrap/lib/cleanup.sh
source "${REPO_DIR}/bootstrap/lib/cleanup.sh"

# Set up traps
trap 'on_error $LINENO' ERR
trap 'on_exit' EXIT

mkdir -p "$LOG_DIR" "$STATE_DIR"

# ── Validate inputs ─────────────────────────────────────────────────────────

: "${APP_NAME:?APP_NAME is required}"

log_section "E2E Test: ${APP_NAME}"
log_info "MARKETPLACE_DIR=${MARKETPLACE_DIR}"
log_info "APPS_DIR=${APPS_DIR}"

write_state "$STATE_VALIDATING"

validate_required_env APP_NAME
validate_app_exists "$APP_NAME"

# ── Generate test parameters ────────────────────────────────────────────────

# shellcheck source=generate-params.sh
source "${SCRIPT_DIR}/generate-params.sh"
load_test_params "$APP_NAME"

validate_parameters "$APP_NAME"
log_info "Validation passed."

# ── Deploy application ──────────────────────────────────────────────────────

write_state "$STATE_DEPLOYING"
log_section "Deploying ${APP_NAME}"

# shellcheck source=../../bootstrap/deploy-app.sh
source "${REPO_DIR}/bootstrap/deploy-app.sh"
deploy_app

log_info "Deployment succeeded."

# ── Health checks ────────────────────────────────────────────────────────────

write_state "$STATE_HEALTHCHECK"
log_section "Health checking ${APP_NAME}"

# shellcheck source=../../bootstrap/healthcheck.sh
source "${REPO_DIR}/bootstrap/healthcheck.sh"

# Determine whether to run full or generic-only health checks.
# SSL-enabled apps have healthcheck hooks that curl https:// which won't work
# without cert-manager. Non-SSL apps use kubectl exec checks that work in k3d.
ssl_enabled="$(yq -r '.ssl.enabled // false' "${APPS_DIR}/${APP_NAME}/app.yaml")"

if [[ "$ssl_enabled" == "true" ]]; then
    log_info "SSL app — running generic health checks only (pods + endpoints)."
    run_generic_healthcheck
else
    log_info "Non-SSL app — running full health checks (including app-specific hook)."
    run_healthcheck
fi

# ── Done ─────────────────────────────────────────────────────────────────────

write_state "$STATE_READY"
log_section "E2E PASSED: ${APP_NAME}"
