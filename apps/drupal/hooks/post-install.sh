#!/usr/bin/env bash
# post-install.sh — Drupal post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[drupal/post-install] Drupal deployed successfully."
log_info "[drupal/post-install] Site:  https://${PARAM_DRUPAL_HOSTNAME:-<unknown>}"
log_info "[drupal/post-install] Admin: https://${PARAM_DRUPAL_HOSTNAME:-<unknown>}/user/login"
log_info "[drupal/post-install] Note: TLS cert may take 60-120 seconds to provision."
