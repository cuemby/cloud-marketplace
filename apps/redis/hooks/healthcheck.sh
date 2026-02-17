#!/usr/bin/env bash
# healthcheck.sh — Redis-specific health check.
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

check_redis_ping() {
    local namespace="${HELM_NAMESPACE_PREFIX}redis"
    log_info "[redis/healthcheck] Checking Redis PING via kubectl exec..."

    retry_with_timeout 120 10 _redis_responds "$namespace"

    log_info "[redis/healthcheck] Redis is responding to PING."
}

_redis_responds() {
    local namespace="$1"
    local pod
    pod="$(kubectl get pods -n "$namespace" \
        -l app.kubernetes.io/component=master \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"

    [[ -n "$pod" ]] || return 1

    local result
    result="$(kubectl exec -n "$namespace" "$pod" -- \
        sh -c 'redis-cli -a "$REDIS_PASSWORD" --no-auth-warning ping' 2>/dev/null)" || return 1

    [[ "$result" == "PONG" ]]
}

check_redis_ping
