#!/usr/bin/env bash
# post-install.sh — FerretDB post-install hook.
# Waits for the FerretDB pod to be ready and logs access information.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}ferretdb"

log_info "[ferretdb/post-install] Waiting for FerretDB to be ready..."

# --- Wait for FerretDB pod to be ready ---
_get_ferretdb_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=ferretdb,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_ferretdb_pod_ready() {
    local pod
    pod="$(_get_ferretdb_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _ferretdb_pod_ready

ferretdb_pod="$(_get_ferretdb_pod)"
log_info "[ferretdb/post-install] FerretDB pod ready: ${ferretdb_pod}"

# --- Log access info ---
local_port="${PARAM_FERRETDB_NODEPORT:-30017}"
log_info "[ferretdb/post-install] FerretDB MongoDB-compatible endpoint: mongodb://<VM-IP>:${local_port}"
log_info "[ferretdb/post-install] Connect with: mongosh mongodb://<VM-IP>:${local_port}"
