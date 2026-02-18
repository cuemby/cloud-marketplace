#!/usr/bin/env bash
# post-install.sh — Matomo post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[matomo/post-install] Matomo deployed successfully."
log_info "[matomo/post-install] Access: https://${PARAM_MATOMO_HOSTNAME:-<unknown>}"
log_info "[matomo/post-install] Note: TLS cert may take 60-120 seconds to provision."
