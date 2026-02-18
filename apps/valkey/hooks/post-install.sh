#!/usr/bin/env bash
# post-install.sh — Valkey post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[valkey/post-install] Valkey deployed successfully."
log_info "[valkey/post-install] Connect: valkey-cli -h <VM_IP> -p 30637 -a <password>"
