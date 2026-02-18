#!/usr/bin/env bash
# post-install.sh — NATS post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[nats/post-install] NATS deployed successfully."
log_info "[nats/post-install] Connect: nats-cli -s nats://<VM_IP>:30222"
