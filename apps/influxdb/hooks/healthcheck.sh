#!/usr/bin/env bash
# healthcheck.sh — InfluxDB-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

check_influxdb_ready() {
    local namespace="${HELM_NAMESPACE_PREFIX}influxdb"
    log_info "[influxdb/healthcheck] Checking InfluxDB health..."

    retry_with_timeout 180 10 _influxdb_responds "$namespace"

    log_info "[influxdb/healthcheck] InfluxDB is healthy."
}

_influxdb_responds() {
    local namespace="$1"
    local pod
    pod="$(kubectl get pods -n "$namespace" \
        -l app.kubernetes.io/name=influxdb \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"

    [[ -n "$pod" ]] || return 1

    kubectl exec -n "$namespace" "$pod" -- \
        curl -sf http://localhost:8086/health 2>/dev/null \
        | grep -q '"status":"pass"' || return 1
}

check_influxdb_ready
