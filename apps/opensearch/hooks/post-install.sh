#!/usr/bin/env bash
# post-install.sh — OpenSearch post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[opensearch/post-install] OpenSearch deployed successfully."
log_info "[opensearch/post-install] REST API: curl -u admin:<password> http://<VM_IP>:30921"
