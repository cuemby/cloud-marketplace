#!/usr/bin/env bash
# healthcheck.sh — etcd-specific health check.
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

check_etcd_ready() {
    local namespace="${HELM_NAMESPACE_PREFIX}etcd"
    log_info "[etcd/healthcheck] Checking etcd health..."

    retry_with_timeout 120 10 _etcd_responds "$namespace"

    log_info "[etcd/healthcheck] etcd is healthy."
}

_etcd_responds() {
    local namespace="$1"
    local pod
    pod="$(kubectl get pods -n "$namespace" \
        -l app.kubernetes.io/name=etcd \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"

    [[ -n "$pod" ]] || return 1

    kubectl exec -n "$namespace" "$pod" -- \
        etcdctl endpoint health \
        --user="root:${PARAM_ETCD_ROOT_PASSWORD}" 2>/dev/null \
        | grep -q "is healthy" || return 1
}

check_etcd_ready
