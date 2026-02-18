#!/usr/bin/env bash
# post-install.sh — Kafka post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[kafka/post-install] Kafka deployed successfully."
log_info "[kafka/post-install] Bootstrap server: <VM_IP>:30092"
