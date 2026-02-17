#!/usr/bin/env bash
# post-install.sh — WordPress post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"

log_info "[wordpress/post-install] WordPress deployed successfully."
log_info "[wordpress/post-install] Access: http://<VM_IP>:${DEFAULT_HTTP_NODEPORT}"
