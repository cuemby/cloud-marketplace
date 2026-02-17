#!/usr/bin/env bash
# post-install.sh — WordPress post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[wordpress/post-install] WordPress deployed successfully."
log_info "[wordpress/post-install] Site:  https://${PARAM_WORDPRESS_HOSTNAME:-<unknown>}"
log_info "[wordpress/post-install] Admin: https://${PARAM_WORDPRESS_HOSTNAME:-<unknown>}/wp-admin"
log_info "[wordpress/post-install] Note: TLS cert may take 60-120 seconds to provision."
