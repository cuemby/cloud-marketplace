#!/usr/bin/env bash
# post-install.sh — InfluxDB post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[influxdb/post-install] InfluxDB deployed successfully."
log_info "[influxdb/post-install] UI:  http://<VM_IP>:30086"
log_info "[influxdb/post-install] API: curl -H 'Authorization: Token <admin-token>' http://<VM_IP>:30086/api/v2/buckets"
