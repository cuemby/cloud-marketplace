#!/usr/bin/env bash
# post-install.sh — Ghost post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[ghost/post-install] Ghost deployed successfully."
log_info "[ghost/post-install] Site:  https://${PARAM_GHOST_HOSTNAME:-<unknown>}"
log_info "[ghost/post-install] Admin: https://${PARAM_GHOST_HOSTNAME:-<unknown>}/ghost"
log_info "[ghost/post-install] Note: TLS cert may take 60-120 seconds to provision."
