#!/usr/bin/env bash
# healthcheck.sh — Mastodon-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_MASTODON_HOSTNAME is expected to be set by the pre-install hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_mastodon_hostname="${PARAM_MASTODON_HOSTNAME:?PARAM_MASTODON_HOSTNAME is required}"

check_mastodon_https() {
    log_info "[mastodon/healthcheck] Checking HTTPS at ${_mastodon_hostname}..."

    retry_with_timeout 300 15 _mastodon_responds

    log_info "[mastodon/healthcheck] Mastodon is responding at https://${_mastodon_hostname}."
}

_mastodon_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 15 --location "https://${_mastodon_hostname}/" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

check_mastodon_https
