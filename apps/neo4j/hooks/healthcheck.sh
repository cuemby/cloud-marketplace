#!/usr/bin/env bash
# healthcheck.sh — Neo4j-specific health check.
# Called by the generic healthcheck after pod/service checks pass.
# PARAM_NEO4J_HOSTNAME is expected to be set by the pre-install hook.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

_neo4j_hostname="${PARAM_NEO4J_HOSTNAME:?PARAM_NEO4J_HOSTNAME is required}"

check_neo4j_https() {
    log_info "[neo4j/healthcheck] Checking HTTPS at ${_neo4j_hostname}..."

    retry_with_timeout 420 15 _neo4j_responds

    log_info "[neo4j/healthcheck] Neo4j is responding at https://${_neo4j_hostname}."
}

_neo4j_responds() {
    local status_code
    status_code="$(curl -sf -o /dev/null -w '%{http_code}' \
        --max-time 15 --location "https://${_neo4j_hostname}/" 2>/dev/null || true)"
    [[ "$status_code" =~ ^(200|301|302)$ ]]
}

check_neo4j_https
