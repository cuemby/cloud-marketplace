#!/usr/bin/env bash
# post-install.sh — Redis post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[redis/post-install] Redis deployed successfully."
log_info "[redis/post-install] Connect: redis-cli -h <VM_IP> -p 30379 -a <password>"
