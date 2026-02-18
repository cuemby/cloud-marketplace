#!/usr/bin/env bash
# pre-install.sh — WordPress pre-install hook.
# Generates missing passwords, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_WP_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"

log_info "[wordpress/pre-install] Setting defaults and generating credentials..."

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
    log_info "[wordpress/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

if _needs_value "${PARAM_MARIADB_ROOT_PASSWORD:-}"; then
    PARAM_MARIADB_ROOT_PASSWORD="$(_generate_password)"
    export PARAM_MARIADB_ROOT_PASSWORD
    log_info "[wordpress/pre-install] Generated MariaDB root password."
fi

if _needs_value "${PARAM_MARIADB_PASSWORD:-}"; then
    PARAM_MARIADB_PASSWORD="$(_generate_password)"
    export PARAM_MARIADB_PASSWORD
    log_info "[wordpress/pre-install] Generated MariaDB user password."
fi

if _needs_value "${PARAM_WORDPRESS_ADMIN_PASSWORD:-}"; then
    PARAM_WORDPRESS_ADMIN_PASSWORD="$(_generate_password)"
    export PARAM_WORDPRESS_ADMIN_PASSWORD
    log_info "[wordpress/pre-install] Generated WordPress admin password."
fi

# --- Non-secret parameter defaults ---
# _needs_value also catches uninterpolated {{placeholders}} from Cuemby Cloud
_needs_value "${PARAM_WORDPRESS_ADMIN_USER:-}" && PARAM_WORDPRESS_ADMIN_USER="admin"
_needs_value "${PARAM_WORDPRESS_ADMIN_EMAIL:-}" && PARAM_WORDPRESS_ADMIN_EMAIL="admin@example.com"
_needs_value "${PARAM_WORDPRESS_SITE_TITLE:-}" && PARAM_WORDPRESS_SITE_TITLE="My WordPress Site"
_needs_value "${PARAM_WORDPRESS_DATA_SIZE:-}" && PARAM_WORDPRESS_DATA_SIZE="10Gi"
_needs_value "${PARAM_MARIADB_DATA_SIZE:-}" && PARAM_MARIADB_DATA_SIZE="5Gi"
export PARAM_WORDPRESS_ADMIN_USER
export PARAM_WORDPRESS_ADMIN_EMAIL
export PARAM_WORDPRESS_SITE_TITLE
export PARAM_WORDPRESS_DATA_SIZE
export PARAM_MARIADB_DATA_SIZE

# --- NodePort ---
export PARAM_HTTP_NODEPORT="${PARAM_HTTP_NODEPORT:-${DEFAULT_HTTP_NODEPORT}}"

# --- Resource limits (defaults target a 2-CPU / 4GB VM) ---
export PARAM_MARIADB_CPU_REQUEST="${PARAM_MARIADB_CPU_REQUEST:-250m}"
export PARAM_MARIADB_CPU_LIMIT="${PARAM_MARIADB_CPU_LIMIT:-1000m}"
export PARAM_MARIADB_MEMORY_REQUEST="${PARAM_MARIADB_MEMORY_REQUEST:-512Mi}"
export PARAM_MARIADB_MEMORY_LIMIT="${PARAM_MARIADB_MEMORY_LIMIT:-1Gi}"

export PARAM_WORDPRESS_CPU_REQUEST="${PARAM_WORDPRESS_CPU_REQUEST:-250m}"
export PARAM_WORDPRESS_CPU_LIMIT="${PARAM_WORDPRESS_CPU_LIMIT:-1000m}"
export PARAM_WORDPRESS_MEMORY_REQUEST="${PARAM_WORDPRESS_MEMORY_REQUEST:-512Mi}"
export PARAM_WORDPRESS_MEMORY_LIMIT="${PARAM_WORDPRESS_MEMORY_LIMIT:-2Gi}"

log_info "[wordpress/pre-install] Pre-install complete."
readonly _WP_PRE_INSTALL_DONE=1
export _WP_PRE_INSTALL_DONE
