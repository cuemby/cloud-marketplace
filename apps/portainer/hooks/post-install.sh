#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

source "${BOOTSTRAP_DIR}/lib/logging.sh"
source "${BOOTSTRAP_DIR}/lib/constants.sh"
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}portainer"

log_info "[portainer/post-install] Waiting for Portainer CE to be ready..."

_get_portainer_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=portainer,app.kubernetes.io/component=portainer \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_portainer_pod_ready() {
    local pod
    pod="$(_get_portainer_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _portainer_pod_ready

portainer_pod="$(_get_portainer_pod)"
log_info "[portainer/post-install] Portainer CE pod ready: ${portainer_pod}"

# --- Create admin user via API (prevents timeout lockout) ---
local_svc_ip
local_svc_ip="$(kubectl get svc portainer -n "${local_namespace}" \
    -o jsonpath='{.spec.clusterIP}' 2>/dev/null)"

_admin_not_exists() {
    local status
    status="$(curl -s -o /dev/null -w '%{http_code}' \
        "http://${local_svc_ip}:9000/api/users/admin/check" 2>/dev/null)"
    [[ "$status" == "404" ]]
}

if _admin_not_exists; then
    log_info "[portainer/post-install] Creating admin user via API..."
    local_admin_pass="${PARAM_PORTAINER_ADMIN_PASSWORD:-}"
    curl -s -X POST "http://${local_svc_ip}:9000/api/users/admin/init" \
        -H "Content-Type: application/json" \
        -d "{\"Username\":\"admin\",\"Password\":\"${local_admin_pass}\"}" >/dev/null 2>&1
    log_info "[portainer/post-install] Admin user created."
else
    log_info "[portainer/post-install] Admin user already exists, skipping."
fi

local_port="${PARAM_PORTAINER_NODEPORT:-30900}"
log_info "[portainer/post-install] Web UI: http://<VM-IP>:${local_port}"
log_info "[portainer/post-install] Login: admin / <PARAM_PORTAINER_ADMIN_PASSWORD>"
