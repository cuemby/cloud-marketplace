#!/usr/bin/env bash
# post-install.sh — MySQL post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[mysql/post-install] MySQL deployed successfully."
log_info "[mysql/post-install] Connect: mysql -h <VM_IP> -P 30306 -u root -p"
