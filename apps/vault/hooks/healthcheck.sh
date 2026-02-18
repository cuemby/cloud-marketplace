#!/usr/bin/env bash
# healthcheck.sh — Vault-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_VAULT_HOSTNAME is expected to be set by the pre-install hook.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_vault_hostname="${PARAM_VAULT_HOSTNAME:?PARAM_VAULT_HOSTNAME is required}"

check_vault_https() {
    log_info "[vault/healthcheck] Checking HTTPS at ${_vault_hostname}..."

    retry_with_timeout 180 10 _vault_responds

    log_info "[vault/healthcheck] Vault is responding at https://${_vault_hostname}."
}

_vault_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 10 "https://${_vault_hostname}/v1/sys/health" 2>/dev/null || true)"
    # 200=initialized+unsealed, 429=standby, 472=perf-standby, 501=not-init, 503=sealed
    [[ "$status_code" =~ ^(200|429|472|501|503)$ ]]
}

check_vault_https
