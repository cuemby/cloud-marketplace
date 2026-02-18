#!/usr/bin/env bash
# post-install.sh — MongoDB post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[mongodb/post-install] MongoDB deployed successfully."
log_info "[mongodb/post-install] Connect: mongosh --host <VM_IP> --port 30017 -u root -p"
