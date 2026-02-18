#!/usr/bin/env bash
# post-install.sh — phpMyAdmin post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[phpmyadmin/post-install] phpMyAdmin deployed successfully."
log_info "[phpmyadmin/post-install] Access: https://${PARAM_PHPMYADMIN_HOSTNAME:-<unknown>}"
log_info "[phpmyadmin/post-install] Note: TLS cert may take 60-120 seconds to provision."
