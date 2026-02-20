#!/usr/bin/env bash
# pre-install.sh — Ghost pre-install hook.
# Generates missing passwords, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_GHOST_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/ssl-hooks.sh
source "${BOOTSTRAP_DIR}/lib/ssl-hooks.sh"

log_info "[ghost/pre-install] Setting defaults and generating credentials..."

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
    log_info "[ghost/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

if _needs_value "${PARAM_GHOST_DB_ROOT_PASSWORD:-}"; then
    PARAM_GHOST_DB_ROOT_PASSWORD="$(_generate_password)"
    export PARAM_GHOST_DB_ROOT_PASSWORD
    log_info "[ghost/pre-install] Generated MySQL root password."
fi

if _needs_value "${PARAM_GHOST_DB_PASSWORD:-}"; then
    PARAM_GHOST_DB_PASSWORD="$(_generate_password)"
    export PARAM_GHOST_DB_PASSWORD
    log_info "[ghost/pre-install] Generated MySQL user password."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_GHOST_DB_DATA_SIZE:-}" && PARAM_GHOST_DB_DATA_SIZE="5Gi"
_needs_value "${PARAM_GHOST_DATA_SIZE:-}" && PARAM_GHOST_DATA_SIZE="10Gi"
export PARAM_GHOST_DB_DATA_SIZE
export PARAM_GHOST_DATA_SIZE

# --- NodePort ---
export PARAM_HTTP_NODEPORT="${PARAM_HTTP_NODEPORT:-${DEFAULT_HTTP_NODEPORT}}"

# --- Resource limits (defaults target a 2-CPU / 4GB VM) ---
export PARAM_MYSQL_CPU_REQUEST="${PARAM_MYSQL_CPU_REQUEST:-250m}"
export PARAM_MYSQL_CPU_LIMIT="${PARAM_MYSQL_CPU_LIMIT:-1000m}"
export PARAM_MYSQL_MEMORY_REQUEST="${PARAM_MYSQL_MEMORY_REQUEST:-512Mi}"
export PARAM_MYSQL_MEMORY_LIMIT="${PARAM_MYSQL_MEMORY_LIMIT:-1Gi}"

export PARAM_GHOST_CPU_REQUEST="${PARAM_GHOST_CPU_REQUEST:-250m}"
export PARAM_GHOST_CPU_LIMIT="${PARAM_GHOST_CPU_LIMIT:-1000m}"
export PARAM_GHOST_MEMORY_REQUEST="${PARAM_GHOST_MEMORY_REQUEST:-512Mi}"
export PARAM_GHOST_MEMORY_LIMIT="${PARAM_GHOST_MEMORY_LIMIT:-2Gi}"

# --- SSL / HTTPS ---
_needs_value "${PARAM_GHOST_SSL_ENABLED:-}" && PARAM_GHOST_SSL_ENABLED="true"
export PARAM_GHOST_SSL_ENABLED

if [[ "${PARAM_GHOST_SSL_ENABLED}" == "true" ]]; then
    if ! _needs_value "${PARAM_GHOST_HOSTNAME:-}"; then
        PARAM_HOSTNAME="${PARAM_GHOST_HOSTNAME}"
        export PARAM_HOSTNAME
    fi
    ssl_full_setup "ghost" "PARAM_HOSTNAME" "ghost-http" 80
    PARAM_GHOST_HOSTNAME="${SSL_HOSTNAME}"
    export PARAM_GHOST_HOSTNAME
    log_info "[ghost/pre-install] SSL enabled — HTTPS hostname: ${SSL_HOSTNAME}"
else
    log_info "[ghost/pre-install] SSL disabled — access via NodePort only."
fi

log_info "[ghost/pre-install] Pre-install complete."
readonly _GHOST_PRE_INSTALL_DONE=1
export _GHOST_PRE_INSTALL_DONE
