#!/usr/bin/env bash
# post-install.sh — Odoo post-install hook.
# Waits for the Odoo pod to be ready and logs access information.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}odoo"

log_info "[odoo/post-install] Waiting for Odoo to be ready..."

# --- Wait for Odoo pod to be ready ---
_get_odoo_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=odoo,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_odoo_pod_ready() {
    local pod
    pod="$(_get_odoo_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _odoo_pod_ready

odoo_pod="$(_get_odoo_pod)"
log_info "[odoo/post-install] Odoo pod ready: ${odoo_pod}"

# --- Log access info ---
local_port="${PARAM_ODOO_NODEPORT:-30069}"
log_info "[odoo/post-install] Odoo web UI: http://<VM-IP>:${local_port}"
log_info "[odoo/post-install] Use the admin master password to create your first database."
