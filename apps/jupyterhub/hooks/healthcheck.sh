#!/usr/bin/env bash
# healthcheck.sh — JupyterHub-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_JUPYTERHUB_HOSTNAME is expected to be set by the pre-install hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_jupyterhub_hostname="${PARAM_JUPYTERHUB_HOSTNAME:?PARAM_JUPYTERHUB_HOSTNAME is required}"

check_jupyterhub_https() {
    log_info "[jupyterhub/healthcheck] Checking HTTPS at ${_jupyterhub_hostname}..."

    retry_with_timeout 300 15 _jupyterhub_responds

    log_info "[jupyterhub/healthcheck] JupyterHub is responding at https://${_jupyterhub_hostname}."
}

_jupyterhub_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 15 --location "https://${_jupyterhub_hostname}/hub/login" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

check_jupyterhub_https
