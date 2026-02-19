#!/usr/bin/env bash
# healthcheck.sh — HAProxy-specific health check.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}haproxy"

# Check 1: HAProxy pod is Ready (Kubernetes probes verify /healthz endpoint)
_haproxy_health_ready() {
    local ready
    ready="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=haproxy,app.kubernetes.io/component=proxy \
        -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)"
    [[ "$ready" == "True" ]]
}

log_info "[haproxy/healthcheck] Checking HAProxy health endpoint..."
retry_with_timeout 120 10 _haproxy_health_ready
log_info "[haproxy/healthcheck] HAProxy health endpoint is responding."

# Check 2: Stats port is open (haproxy image includes socat)
_haproxy_stats_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=haproxy,app.kubernetes.io/component=proxy \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    kubectl exec -n "${local_namespace}" "$pod" -- \
        socat /dev/null TCP:localhost:8936,connect-timeout=5 2>/dev/null
}

log_info "[haproxy/healthcheck] Checking stats interface..."
retry_with_timeout 120 10 _haproxy_stats_ready
log_info "[haproxy/healthcheck] Stats interface is accessible."
