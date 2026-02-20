#!/usr/bin/env bash
# pre-install.sh — Neo4j pre-install hook.
# Generates missing passwords, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_NEO4J_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/ssl-hooks.sh
source "${BOOTSTRAP_DIR}/lib/ssl-hooks.sh"

log_info "[neo4j/pre-install] Setting defaults and generating credentials..."

# --- Password generation (alphanumeric only to avoid YAML escaping issues) ---
_generate_password() {
    openssl rand -base64 24 | tr -d '/+=' | head -c 32
}

# Check if a value is empty or an uninterpolated {{placeholder}}
_needs_value() {
    local val="${1:-}"
    [[ -z "$val" || "$val" == \{\{*\}\} ]]
}

# Clear APP_VERSION if it's an uninterpolated placeholder (use default from app.yaml)
if _needs_value "${APP_VERSION:-}"; then
    unset APP_VERSION
    log_info "[neo4j/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Credential generation ---
if _needs_value "${PARAM_NEO4J_AUTH_PASSWORD:-}"; then
    PARAM_NEO4J_AUTH_PASSWORD="$(_generate_password)"
    export PARAM_NEO4J_AUTH_PASSWORD
    log_info "[neo4j/pre-install] Generated Neo4j authentication password."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_NEO4J_DATA_SIZE:-}" && PARAM_NEO4J_DATA_SIZE="10Gi"
_needs_value "${PARAM_NEO4J_HEAP_SIZE:-}" && PARAM_NEO4J_HEAP_SIZE="512m"
export PARAM_NEO4J_DATA_SIZE
export PARAM_NEO4J_HEAP_SIZE

# --- NodePorts ---
_needs_value "${PARAM_NEO4J_HTTP_NODEPORT:-}" && PARAM_NEO4J_HTTP_NODEPORT="30474"
_needs_value "${PARAM_NEO4J_BOLT_NODEPORT:-}" && PARAM_NEO4J_BOLT_NODEPORT="30687"
export PARAM_NEO4J_HTTP_NODEPORT
export PARAM_NEO4J_BOLT_NODEPORT

# --- Resource limits (defaults target a 2-CPU / 4GB VM) ---
export PARAM_NEO4J_CPU_REQUEST="${PARAM_NEO4J_CPU_REQUEST:-250m}"
export PARAM_NEO4J_CPU_LIMIT="${PARAM_NEO4J_CPU_LIMIT:-2000m}"
export PARAM_NEO4J_MEMORY_REQUEST="${PARAM_NEO4J_MEMORY_REQUEST:-512Mi}"
export PARAM_NEO4J_MEMORY_LIMIT="${PARAM_NEO4J_MEMORY_LIMIT:-3072Mi}"

# --- SSL / HTTPS ---
_needs_value "${PARAM_NEO4J_SSL_ENABLED:-}" && PARAM_NEO4J_SSL_ENABLED="true"
export PARAM_NEO4J_SSL_ENABLED

if [[ "${PARAM_NEO4J_SSL_ENABLED}" == "true" ]]; then
    if ! _needs_value "${PARAM_NEO4J_HOSTNAME:-}"; then
        PARAM_HOSTNAME="${PARAM_NEO4J_HOSTNAME}"
        export PARAM_HOSTNAME
    fi
    ssl_full_setup "neo4j" "PARAM_HOSTNAME" "neo4j-http" 80
    PARAM_NEO4J_HOSTNAME="${SSL_HOSTNAME}"
    export PARAM_NEO4J_HOSTNAME
    log_info "[neo4j/pre-install] SSL enabled — HTTPS hostname: ${SSL_HOSTNAME}"
else
    log_info "[neo4j/pre-install] SSL disabled — access via NodePort only."
fi

log_info "[neo4j/pre-install] Pre-install complete."
readonly _NEO4J_PRE_INSTALL_DONE=1
export _NEO4J_PRE_INSTALL_DONE
