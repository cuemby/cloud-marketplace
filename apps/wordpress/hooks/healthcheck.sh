#!/usr/bin/env bash
# healthcheck.sh — WordPress-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

check_wordpress_http() {
    local port="${DEFAULT_HTTP_NODEPORT}"
    log_info "[wordpress/healthcheck] Checking HTTP on port ${port}..."

    retry_with_timeout 120 10 _wp_responds "$port"

    log_info "[wordpress/healthcheck] WordPress is responding on port ${port}."
}

_wp_responds() {
    local port="$1"
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 10 "http://localhost:${port}/" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

check_wordpress_http
