#!/usr/bin/env bash
# post-install.sh — Nextcloud post-install hook.
# Waits for the Nextcloud pod to be ready and logs access information.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}nextcloud"

log_info "[nextcloud/post-install] Waiting for Nextcloud to be ready..."

# --- Wait for Nextcloud pod to be ready ---
_get_nc_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=nextcloud,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_nc_pod_ready() {
    local pod
    pod="$(_get_nc_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 600 10 _nc_pod_ready

nc_pod="$(_get_nc_pod)"
log_info "[nextcloud/post-install] Nextcloud pod ready: ${nc_pod}"

# --- Configure reverse proxy settings (required for HTTPS via Traefik Gateway) ---
if [[ "${PARAM_NEXTCLOUD_SSL_ENABLED:-false}" == "true" ]]; then
    local_hostname="${PARAM_NEXTCLOUD_HOSTNAME:-localhost}"
    log_info "[nextcloud/post-install] Configuring reverse proxy settings for HTTPS..."

    _occ() {
        kubectl exec -n "${local_namespace}" "${nc_pod}" -c nextcloud -- \
            su -s /bin/bash www-data -c "php /var/www/html/occ $*" 2>/dev/null
    }

    _occ "config:system:set overwriteprotocol --value=https"
    _occ "config:system:set overwrite.cli.url --value=https://${local_hostname}"
    _occ "config:system:set trusted_proxies 0 --value=10.42.0.0/16"
    _occ "config:system:set trusted_proxies 1 --value=10.43.0.0/16"
    _occ "config:system:set forwarded_for_headers 0 --value=HTTP_X_FORWARDED_FOR"

    log_info "[nextcloud/post-install] Reverse proxy settings applied."
fi

# --- Log access info ---
local_port="${PARAM_HTTP_NODEPORT:-${DEFAULT_HTTP_NODEPORT}}"
log_info "[nextcloud/post-install] Web UI: http://<VM-IP>:${local_port}"
log_info "[nextcloud/post-install] Status: http://<VM-IP>:${local_port}/status.php"
log_info "[nextcloud/post-install] Username: ${PARAM_NEXTCLOUD_ADMIN_USER:-admin}"
