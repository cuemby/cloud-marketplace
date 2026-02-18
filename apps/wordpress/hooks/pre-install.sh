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

if [[ -z "${PARAM_MARIADB_ROOT_PASSWORD:-}" ]]; then
    PARAM_MARIADB_ROOT_PASSWORD="$(_generate_password)"
    export PARAM_MARIADB_ROOT_PASSWORD
    log_info "[wordpress/pre-install] Generated MariaDB root password."
fi

if [[ -z "${PARAM_MARIADB_PASSWORD:-}" ]]; then
    PARAM_MARIADB_PASSWORD="$(_generate_password)"
    export PARAM_MARIADB_PASSWORD
    log_info "[wordpress/pre-install] Generated MariaDB user password."
fi

if [[ -z "${PARAM_WORDPRESS_ADMIN_PASSWORD:-}" ]]; then
    PARAM_WORDPRESS_ADMIN_PASSWORD="$(_generate_password)"
    export PARAM_WORDPRESS_ADMIN_PASSWORD
    log_info "[wordpress/pre-install] Generated WordPress admin password."
fi

# --- Non-secret parameter defaults ---
export PARAM_WORDPRESS_ADMIN_USER="${PARAM_WORDPRESS_ADMIN_USER:-admin}"
export PARAM_WORDPRESS_ADMIN_EMAIL="${PARAM_WORDPRESS_ADMIN_EMAIL:-admin@example.com}"
export PARAM_WORDPRESS_SITE_TITLE="${PARAM_WORDPRESS_SITE_TITLE:-My WordPress Site}"
export PARAM_WORDPRESS_DATA_SIZE="${PARAM_WORDPRESS_DATA_SIZE:-10Gi}"
export PARAM_MARIADB_DATA_SIZE="${PARAM_MARIADB_DATA_SIZE:-5Gi}"

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
