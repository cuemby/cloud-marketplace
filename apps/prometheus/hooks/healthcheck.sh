#!/usr/bin/env bash
# healthcheck.sh — Prometheus-specific health check.
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

check_prometheus_ready() {
    local namespace="${HELM_NAMESPACE_PREFIX}prometheus"
    log_info "[prometheus/healthcheck] Checking Prometheus health..."

    retry_with_timeout 180 10 _prometheus_responds "$namespace"

    log_info "[prometheus/healthcheck] Prometheus is healthy."
}

_prometheus_responds() {
    local namespace="$1"
    local pod
    pod="$(kubectl get pods -n "$namespace" \
        -l app.kubernetes.io/component=server \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"

    [[ -n "$pod" ]] || return 1

    kubectl exec -n "$namespace" "$pod" -- \
        wget -qO- http://localhost:9090/-/healthy 2>/dev/null \
        | grep -q "Prometheus Server is Healthy" || return 1
}

check_prometheus_ready
