#!/usr/bin/env bash
# post-install.sh — Appsmith post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[appsmith/post-install] Appsmith deployed successfully."
log_info "[appsmith/post-install] URL:  https://${PARAM_APPSMITH_HOSTNAME:-<unknown>}"
log_info "[appsmith/post-install] Note: TLS cert may take 60-120 seconds to provision."
