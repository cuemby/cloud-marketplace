#!/usr/bin/env bash
# post-install.sh — Discourse post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[discourse/post-install] Discourse deployed successfully."
log_info "[discourse/post-install] Site: https://${PARAM_DISCOURSE_HOSTNAME:-<unknown>}"
log_info "[discourse/post-install] Note: TLS cert may take 60-120 seconds to provision."
log_info "[discourse/post-install] Note: Discourse initial setup may take several minutes."
