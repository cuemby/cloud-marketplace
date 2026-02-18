#!/usr/bin/env bash
# healthcheck.sh — MinIO-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_MINIO_HOSTNAME is expected to be set by the pre-install hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_minio_hostname="${PARAM_MINIO_HOSTNAME:?PARAM_MINIO_HOSTNAME is required}"

check_minio_https() {
    log_info "[minio/healthcheck] Checking HTTPS at ${_minio_hostname}..."

    retry_with_timeout 300 15 _minio_responds

    log_info "[minio/healthcheck] MinIO is responding at https://${_minio_hostname}."
}

_minio_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 15 --location "https://${_minio_hostname}/minio/health/live" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

check_minio_https
