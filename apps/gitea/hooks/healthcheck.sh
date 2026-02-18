#!/usr/bin/env bash
# healthcheck.sh — Gitea-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_GITEA_HOSTNAME is expected to be set by the pre-install hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_gitea_hostname="${PARAM_GITEA_HOSTNAME:?PARAM_GITEA_HOSTNAME is required}"

check_gitea_https() {
    log_info "[gitea/healthcheck] Checking HTTPS at ${_gitea_hostname}..."

    retry_with_timeout 300 15 _gitea_responds

    log_info "[gitea/healthcheck] Gitea is responding at https://${_gitea_hostname}."
}

_gitea_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 15 --location "https://${_gitea_hostname}/api/v1/version" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

check_gitea_https
