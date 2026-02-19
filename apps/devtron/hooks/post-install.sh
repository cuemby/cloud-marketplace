#!/usr/bin/env bash
# post-install.sh — Devtron post-install hook.
# Waits for PostgreSQL, NATS, orchestrator, and dashboard to be ready.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}devtron"

# --- Wait for PostgreSQL to be ready ---
log_info "[devtron/post-install] Waiting for PostgreSQL to be ready..."

_pg_pod_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=devtron,app.kubernetes.io/component=database \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _pg_pod_ready
log_info "[devtron/post-install] PostgreSQL is ready."

# --- Wait for NATS to be ready ---
log_info "[devtron/post-install] Waiting for NATS to be ready..."

_nats_pod_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=devtron,app.kubernetes.io/component=nats \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 120 10 _nats_pod_ready
log_info "[devtron/post-install] NATS is ready."

# --- Wait for orchestrator to be ready ---
log_info "[devtron/post-install] Waiting for Devtron orchestrator to be ready..."

_orchestrator_pod_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=devtron,app.kubernetes.io/component=orchestrator \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 600 15 _orchestrator_pod_ready
log_info "[devtron/post-install] Devtron orchestrator is ready."

# --- Wait for dashboard to be ready ---
log_info "[devtron/post-install] Waiting for Devtron dashboard to be ready..."

_dashboard_pod_ready() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=devtron,app.kubernetes.io/component=dashboard \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _dashboard_pod_ready
log_info "[devtron/post-install] Devtron dashboard is ready."

# --- Log access info ---
log_info "[devtron/post-install] Devtron Dashboard: http://<VM-IP>:30080"
log_info "[devtron/post-install] Default admin credentials — change on first login."
log_info "[devtron/post-install] Post-install complete."
