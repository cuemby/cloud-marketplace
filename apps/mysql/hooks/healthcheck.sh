#!/usr/bin/env bash
# healthcheck.sh — MySQL-specific health check.
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

check_mysql_ready() {
    local namespace="${HELM_NAMESPACE_PREFIX}mysql"
    log_info "[mysql/healthcheck] Checking mysqladmin ping via kubectl exec..."

    retry_with_timeout 120 10 _mysql_responds "$namespace"

    log_info "[mysql/healthcheck] MySQL is accepting connections."
}

_mysql_responds() {
    local namespace="$1"
    local pod
    pod="$(kubectl get pods -n "$namespace" \
        -l app.kubernetes.io/component=primary \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"

    [[ -n "$pod" ]] || return 1

    kubectl exec -n "$namespace" "$pod" -- \
        mysqladmin ping -u root -p"$PARAM_MYSQL_ROOT_PASSWORD" 2>/dev/null || return 1
}

check_mysql_ready
