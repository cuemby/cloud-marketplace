#!/usr/bin/env bash
# pre-install.sh — MySQL pre-install hook.
# Generates missing passwords, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_MYSQL_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"

log_info "[mysql/pre-install] Setting defaults and generating credentials..."

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
    log_info "[mysql/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Credential generation ---
if _needs_value "${PARAM_MYSQL_ROOT_PASSWORD:-}"; then
    PARAM_MYSQL_ROOT_PASSWORD="$(_generate_password)"
    export PARAM_MYSQL_ROOT_PASSWORD
    log_info "[mysql/pre-install] Generated MySQL root password."
fi

if _needs_value "${PARAM_MYSQL_PASSWORD:-}"; then
    PARAM_MYSQL_PASSWORD="$(_generate_password)"
    export PARAM_MYSQL_PASSWORD
    log_info "[mysql/pre-install] Generated MySQL user password."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_MYSQL_USER:-}" && PARAM_MYSQL_USER="mysql"
_needs_value "${PARAM_MYSQL_DATABASE:-}" && PARAM_MYSQL_DATABASE="mysql"
_needs_value "${PARAM_MYSQL_DATA_SIZE:-}" && PARAM_MYSQL_DATA_SIZE="10Gi"
export PARAM_MYSQL_USER
export PARAM_MYSQL_DATABASE
export PARAM_MYSQL_DATA_SIZE

# --- NodePort ---
_needs_value "${PARAM_MYSQL_NODEPORT:-}" && PARAM_MYSQL_NODEPORT="30306"
export PARAM_MYSQL_NODEPORT

# --- Resource limits (defaults target a 2-CPU / 4GB VM) ---
export PARAM_MYSQL_CPU_REQUEST="${PARAM_MYSQL_CPU_REQUEST:-250m}"
export PARAM_MYSQL_CPU_LIMIT="${PARAM_MYSQL_CPU_LIMIT:-2000m}"
export PARAM_MYSQL_MEMORY_REQUEST="${PARAM_MYSQL_MEMORY_REQUEST:-512Mi}"
export PARAM_MYSQL_MEMORY_LIMIT="${PARAM_MYSQL_MEMORY_LIMIT:-2Gi}"

log_info "[mysql/pre-install] Pre-install complete."
readonly _MYSQL_PRE_INSTALL_DONE=1
export _MYSQL_PRE_INSTALL_DONE
