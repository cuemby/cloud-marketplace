#!/usr/bin/env bash
# healthcheck.sh — Valkey-specific health check.
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

check_valkey_ping() {
    local namespace="${HELM_NAMESPACE_PREFIX}valkey"
    log_info "[valkey/healthcheck] Checking Valkey PING via kubectl exec..."

    retry_with_timeout 120 10 _valkey_responds "$namespace"

    log_info "[valkey/healthcheck] Valkey is responding to PING."
}

_valkey_responds() {
    local namespace="$1"
    local pod
    pod="$(kubectl get pods -n "$namespace" \
        -l app.kubernetes.io/component=primary \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"

    [[ -n "$pod" ]] || return 1

    local result
    result="$(kubectl exec -n "$namespace" "$pod" -- \
        sh -c 'valkey-cli -a "$(cat /opt/bitnami/valkey/secrets/valkey-password)" --no-auth-warning ping' 2>/dev/null)" || return 1

    [[ "$result" == "PONG" ]]
}

check_valkey_ping
