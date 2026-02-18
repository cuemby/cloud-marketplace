#!/usr/bin/env bash
# healthcheck.sh — Drupal-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_DRUPAL_HOSTNAME is expected to be set by the pre-install hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_drupal_hostname="${PARAM_DRUPAL_HOSTNAME:?PARAM_DRUPAL_HOSTNAME is required}"

check_drupal_https() {
    log_info "[drupal/healthcheck] Checking HTTPS at ${_drupal_hostname}..."

    retry_with_timeout 300 15 _drupal_responds

    log_info "[drupal/healthcheck] Drupal is responding at https://${_drupal_hostname}."
}

_drupal_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 15 --location "https://${_drupal_hostname}/" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

check_drupal_https
