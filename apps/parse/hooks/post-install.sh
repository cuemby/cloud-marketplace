#!/usr/bin/env bash
# post-install.sh — Parse post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[parse/post-install] Parse deployed successfully."
log_info "[parse/post-install] Dashboard: https://${PARAM_PARSE_HOSTNAME:-<unknown>}/dashboard"
log_info "[parse/post-install] API:       https://${PARAM_PARSE_HOSTNAME:-<unknown>}/parse"
log_info "[parse/post-install] Note: TLS cert may take 60-120 seconds to provision."
