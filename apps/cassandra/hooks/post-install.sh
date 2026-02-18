#!/usr/bin/env bash
# post-install.sh — Cassandra post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[cassandra/post-install] Cassandra deployed successfully."
log_info "[cassandra/post-install] Connect: cqlsh <VM_IP> 30942 -u cassandra -p <password>"
