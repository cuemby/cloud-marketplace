#!/usr/bin/env bash
# healthcheck.sh — Cassandra-specific health check.
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

check_cassandra_ready() {
    local namespace="${HELM_NAMESPACE_PREFIX}cassandra"
    log_info "[cassandra/healthcheck] Checking Cassandra CQL connectivity..."

    retry_with_timeout 300 15 _cassandra_responds "$namespace"

    log_info "[cassandra/healthcheck] Cassandra is accepting CQL connections."
}

_cassandra_responds() {
    local namespace="$1"
    local pod
    pod="$(kubectl get pods -n "$namespace" \
        -l app.kubernetes.io/component=cassandra \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"

    [[ -n "$pod" ]] || return 1

    kubectl exec -n "$namespace" "$pod" -- \
        cqlsh localhost 9042 -u cassandra -p "$PARAM_CASSANDRA_PASSWORD" \
        -e "DESCRIBE KEYSPACES" 2>/dev/null || return 1
}

check_cassandra_ready
