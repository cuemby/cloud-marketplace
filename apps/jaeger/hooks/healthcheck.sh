#!/usr/bin/env bash
# healthcheck.sh — Jaeger-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_JAEGER_HOSTNAME is expected to be set by the pre-install hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_jaeger_hostname="${PARAM_JAEGER_HOSTNAME:?PARAM_JAEGER_HOSTNAME is required}"

check_jaeger_https() {
    log_info "[jaeger/healthcheck] Checking HTTPS at ${_jaeger_hostname}..."

    retry_with_timeout 180 15 _jaeger_responds

    log_info "[jaeger/healthcheck] Jaeger is responding at https://${_jaeger_hostname}."
}

_jaeger_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 15 --location "https://${_jaeger_hostname}/" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

check_jaeger_https
