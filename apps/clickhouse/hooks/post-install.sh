#!/usr/bin/env bash
# post-install.sh — ClickHouse post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[clickhouse/post-install] ClickHouse deployed successfully."
log_info "[clickhouse/post-install] HTTP API: curl http://<VM_IP>:30123/?query=SELECT+1"
log_info "[clickhouse/post-install] Native:   clickhouse-client --host <VM_IP> --port 30901 --user default --password <password>"
