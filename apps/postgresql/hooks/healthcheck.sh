#!/usr/bin/env bash
# healthcheck.sh — PostgreSQL-specific health check.
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

check_postgresql_ready() {
    local namespace="${HELM_NAMESPACE_PREFIX}postgresql"
    log_info "[postgresql/healthcheck] Checking pg_isready via kubectl exec..."

    retry_with_timeout 120 10 _pg_responds "$namespace"

    log_info "[postgresql/healthcheck] PostgreSQL is accepting connections."
}

_pg_responds() {
    local namespace="$1"
    local pod
    pod="$(kubectl get pods -n "$namespace" \
        -l app.kubernetes.io/component=primary \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"

    [[ -n "$pod" ]] || return 1

    kubectl exec -n "$namespace" "$pod" -- \
        pg_isready -U postgres 2>/dev/null || return 1
}

check_postgresql_ready
