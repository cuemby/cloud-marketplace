#!/usr/bin/env bash
# healthcheck.sh — Keycloak-specific health check.
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

check_keycloak_health() {
    local namespace="${HELM_NAMESPACE_PREFIX}keycloak"
    log_info "[keycloak/healthcheck] Checking Keycloak health endpoint via kubectl exec..."

    retry_with_timeout 120 10 _keycloak_responds "$namespace"

    log_info "[keycloak/healthcheck] Keycloak is healthy and responding."
}

_keycloak_responds() {
    local namespace="$1"
    local pod
    pod="$(kubectl get pods -n "$namespace" \
        -l app.kubernetes.io/component=keycloak \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"

    [[ -n "$pod" ]] || return 1

    kubectl exec -n "$namespace" "$pod" -- \
        curl -sf http://localhost:8080/health/ready 2>/dev/null || return 1
}

check_keycloak_health
