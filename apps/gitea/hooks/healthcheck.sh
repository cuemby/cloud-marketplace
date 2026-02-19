#!/usr/bin/env bash
# healthcheck.sh — Gitea-specific health checks.
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

local_namespace="${HELM_NAMESPACE_PREFIX}gitea"

# --- Check 1: Gitea HTTP endpoint responds ---
_gitea_is_healthy() {
    local pod
    pod="$(kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=gitea,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$pod" ]] || return 1
    # Gitea image may not have curl; use wget -q --spider for HTTP check.
    # Before install wizard completes, /api/healthz may not return "pass",
    # so we check the root URL responds with any 2xx/3xx status.
    kubectl exec -n "${local_namespace}" "$pod" -- \
        wget -q --spider --timeout=5 http://127.0.0.1:3000/ 2>/dev/null
}

log_info "[gitea/healthcheck] Checking Gitea health..."
retry_with_timeout 120 10 _gitea_is_healthy
log_info "[gitea/healthcheck] Gitea is healthy."

# --- Check 2: PVCs are bound ---
log_info "[gitea/healthcheck] Checking PVC status..."
all_bound=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pvc_name="${line%%=*}"
    pvc_phase="${line##*=}"
    if [[ "$pvc_phase" != "Bound" ]]; then
        log_warn "[gitea/healthcheck] PVC ${pvc_name} is ${pvc_phase}, expected Bound."
        all_bound=false
    fi
done < <(kubectl get pvc -n "${local_namespace}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={"="}{.status.phase}{"\n"}{end}' 2>/dev/null)

if [[ "$all_bound" == "true" ]]; then
    log_info "[gitea/healthcheck] All PVCs are Bound."
else
    log_warn "[gitea/healthcheck] Not all PVCs are Bound."
    exit 1
fi
