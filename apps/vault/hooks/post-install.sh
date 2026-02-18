#!/usr/bin/env bash
# post-install.sh — Vault post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[vault/post-install] Vault deployed successfully."
log_info "[vault/post-install] Dashboard: https://${PARAM_VAULT_HOSTNAME:-<unknown>}"
log_info "[vault/post-install] Note: TLS cert may take 60-120 seconds to provision."
log_info "[vault/post-install] Run 'vault operator init' to initialize Vault (first time only)."
