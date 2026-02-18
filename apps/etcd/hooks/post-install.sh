#!/usr/bin/env bash
# post-install.sh — etcd post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[etcd/post-install] etcd deployed successfully."
log_info "[etcd/post-install] Connect: etcdctl --endpoints=http://<VM_IP>:30239 --user=root:<password> endpoint health"
