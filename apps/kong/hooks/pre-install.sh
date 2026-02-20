#!/usr/bin/env bash
# pre-install.sh — Kong Gateway pre-install hook.
# Generates missing passwords, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_KONG_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/ssl-hooks.sh
source "${BOOTSTRAP_DIR}/lib/ssl-hooks.sh"

log_info "[kong/pre-install] Setting defaults and generating credentials..."

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
    log_info "[kong/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Credential generation ---
if _needs_value "${PARAM_KONG_DB_PASSWORD:-}"; then
    PARAM_KONG_DB_PASSWORD="$(_generate_password)"
    export PARAM_KONG_DB_PASSWORD
    log_info "[kong/pre-install] Generated PostgreSQL password."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_KONG_DB_DATA_SIZE:-}" && PARAM_KONG_DB_DATA_SIZE="5Gi"
export PARAM_KONG_DB_DATA_SIZE

# --- NodePorts ---
_needs_value "${PARAM_KONG_PROXY_NODEPORT:-}" && PARAM_KONG_PROXY_NODEPORT="30800"
export PARAM_KONG_PROXY_NODEPORT

_needs_value "${PARAM_KONG_ADMIN_NODEPORT:-}" && PARAM_KONG_ADMIN_NODEPORT="30801"
export PARAM_KONG_ADMIN_NODEPORT

# --- Resource limits (defaults target a 2-CPU / 4GB VM) ---
# PostgreSQL
export PARAM_KONG_POSTGRES_CPU_REQUEST="${PARAM_KONG_POSTGRES_CPU_REQUEST:-250m}"
export PARAM_KONG_POSTGRES_CPU_LIMIT="${PARAM_KONG_POSTGRES_CPU_LIMIT:-500m}"
export PARAM_KONG_POSTGRES_MEMORY_REQUEST="${PARAM_KONG_POSTGRES_MEMORY_REQUEST:-256Mi}"
export PARAM_KONG_POSTGRES_MEMORY_LIMIT="${PARAM_KONG_POSTGRES_MEMORY_LIMIT:-512Mi}"

# Kong Gateway
export PARAM_KONG_CPU_REQUEST="${PARAM_KONG_CPU_REQUEST:-500m}"
export PARAM_KONG_CPU_LIMIT="${PARAM_KONG_CPU_LIMIT:-1500m}"
export PARAM_KONG_MEMORY_REQUEST="${PARAM_KONG_MEMORY_REQUEST:-512Mi}"
export PARAM_KONG_MEMORY_LIMIT="${PARAM_KONG_MEMORY_LIMIT:-2Gi}"

# --- SSL / HTTPS ---
_needs_value "${PARAM_KONG_SSL_ENABLED:-}" && PARAM_KONG_SSL_ENABLED="true"
export PARAM_KONG_SSL_ENABLED

if [[ "${PARAM_KONG_SSL_ENABLED}" == "true" ]]; then
    if ! _needs_value "${PARAM_KONG_HOSTNAME:-}"; then
        PARAM_HOSTNAME="${PARAM_KONG_HOSTNAME}"
        export PARAM_HOSTNAME
    fi
    ssl_full_setup "kong" "PARAM_HOSTNAME" "kong-proxy-http" 80
    PARAM_KONG_HOSTNAME="${SSL_HOSTNAME}"
    export PARAM_KONG_HOSTNAME
    log_info "[kong/pre-install] SSL enabled — HTTPS hostname: ${SSL_HOSTNAME}"
else
    log_info "[kong/pre-install] SSL disabled — access via NodePort only."
fi

log_info "[kong/pre-install] Pre-install complete."
readonly _KONG_PRE_INSTALL_DONE=1
export _KONG_PRE_INSTALL_DONE
