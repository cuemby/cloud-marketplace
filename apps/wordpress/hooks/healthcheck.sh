#!/usr/bin/env bash
# healthcheck.sh — WordPress-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_WORDPRESS_HOSTNAME is expected to be set by the pre-install hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_wp_hostname="${PARAM_WORDPRESS_HOSTNAME:?PARAM_WORDPRESS_HOSTNAME is required}"

check_wordpress_https() {
    log_info "[wordpress/healthcheck] Checking HTTPS at ${_wp_hostname}..."

    # Allow extra time for cert-manager to provision the certificate
    retry_with_timeout 300 15 _wp_responds

    log_info "[wordpress/healthcheck] WordPress is responding at https://${_wp_hostname}."
}

_wp_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 15 --location "https://${_wp_hostname}/" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

check_wordpress_https
