#!/usr/bin/env bash
# pre-install.sh — Joomla pre-install hook.
# Generates missing passwords, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_JOOMLA_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/ssl-hooks.sh
source "${BOOTSTRAP_DIR}/lib/ssl-hooks.sh"

log_info "[joomla/pre-install] Setting defaults and generating credentials..."

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
    log_info "[joomla/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

if _needs_value "${PARAM_JOOMLA_DB_ROOT_PASSWORD:-}"; then
    PARAM_JOOMLA_DB_ROOT_PASSWORD="$(_generate_password)"
    export PARAM_JOOMLA_DB_ROOT_PASSWORD
    log_info "[joomla/pre-install] Generated MariaDB root password."
fi

if _needs_value "${PARAM_JOOMLA_DB_PASSWORD:-}"; then
    PARAM_JOOMLA_DB_PASSWORD="$(_generate_password)"
    export PARAM_JOOMLA_DB_PASSWORD
    log_info "[joomla/pre-install] Generated MariaDB user password."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_JOOMLA_DB_DATA_SIZE:-}" && PARAM_JOOMLA_DB_DATA_SIZE="5Gi"
_needs_value "${PARAM_JOOMLA_DATA_SIZE:-}" && PARAM_JOOMLA_DATA_SIZE="5Gi"
export PARAM_JOOMLA_DB_DATA_SIZE
export PARAM_JOOMLA_DATA_SIZE

# --- NodePort ---
export PARAM_HTTP_NODEPORT="${PARAM_HTTP_NODEPORT:-${DEFAULT_HTTP_NODEPORT}}"

# --- Resource limits (defaults target a 2-CPU / 4GB VM) ---
export PARAM_MARIADB_CPU_REQUEST="${PARAM_MARIADB_CPU_REQUEST:-250m}"
export PARAM_MARIADB_CPU_LIMIT="${PARAM_MARIADB_CPU_LIMIT:-1000m}"
export PARAM_MARIADB_MEMORY_REQUEST="${PARAM_MARIADB_MEMORY_REQUEST:-512Mi}"
export PARAM_MARIADB_MEMORY_LIMIT="${PARAM_MARIADB_MEMORY_LIMIT:-1Gi}"

export PARAM_JOOMLA_CPU_REQUEST="${PARAM_JOOMLA_CPU_REQUEST:-250m}"
export PARAM_JOOMLA_CPU_LIMIT="${PARAM_JOOMLA_CPU_LIMIT:-1000m}"
export PARAM_JOOMLA_MEMORY_REQUEST="${PARAM_JOOMLA_MEMORY_REQUEST:-512Mi}"
export PARAM_JOOMLA_MEMORY_LIMIT="${PARAM_JOOMLA_MEMORY_LIMIT:-2Gi}"

# --- SSL / HTTPS ---
_needs_value "${PARAM_JOOMLA_SSL_ENABLED:-}" && PARAM_JOOMLA_SSL_ENABLED="true"
export PARAM_JOOMLA_SSL_ENABLED

if [[ "${PARAM_JOOMLA_SSL_ENABLED}" == "true" ]]; then
    if ! _needs_value "${PARAM_JOOMLA_HOSTNAME:-}"; then
        PARAM_HOSTNAME="${PARAM_JOOMLA_HOSTNAME}"
        export PARAM_HOSTNAME
    fi
    ssl_full_setup "joomla" "PARAM_HOSTNAME" "joomla-http" 80
    PARAM_JOOMLA_HOSTNAME="${SSL_HOSTNAME}"
    export PARAM_JOOMLA_HOSTNAME
    log_info "[joomla/pre-install] SSL enabled — HTTPS hostname: ${SSL_HOSTNAME}"
else
    log_info "[joomla/pre-install] SSL disabled — access via NodePort only."
fi

log_info "[joomla/pre-install] Pre-install complete."
readonly _JOOMLA_PRE_INSTALL_DONE=1
export _JOOMLA_PRE_INSTALL_DONE
