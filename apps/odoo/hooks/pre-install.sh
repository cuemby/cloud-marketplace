#!/usr/bin/env bash
# pre-install.sh — Odoo pre-install hook.
# Generates missing passwords, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_ODOO_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/ssl-hooks.sh
source "${BOOTSTRAP_DIR}/lib/ssl-hooks.sh"

log_info "[odoo/pre-install] Setting defaults and generating credentials..."

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
    log_info "[odoo/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Credential generation ---
if _needs_value "${PARAM_ODOO_DB_PASSWORD:-}"; then
    PARAM_ODOO_DB_PASSWORD="$(_generate_password)"
    export PARAM_ODOO_DB_PASSWORD
    log_info "[odoo/pre-install] Generated PostgreSQL password."
fi

if _needs_value "${PARAM_ODOO_ADMIN_PASSWORD:-}"; then
    PARAM_ODOO_ADMIN_PASSWORD="$(_generate_password)"
    export PARAM_ODOO_ADMIN_PASSWORD
    log_info "[odoo/pre-install] Generated admin master password."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_ODOO_DB_DATA_SIZE:-}" && PARAM_ODOO_DB_DATA_SIZE="10Gi"
export PARAM_ODOO_DB_DATA_SIZE

_needs_value "${PARAM_ODOO_DATA_SIZE:-}" && PARAM_ODOO_DATA_SIZE="10Gi"
export PARAM_ODOO_DATA_SIZE

# --- NodePort ---
_needs_value "${PARAM_ODOO_NODEPORT:-}" && PARAM_ODOO_NODEPORT="30069"
export PARAM_ODOO_NODEPORT

# --- Resource limits (defaults target a 2-CPU / 4GB VM) ---
# PostgreSQL
export PARAM_ODOO_POSTGRES_CPU_REQUEST="${PARAM_ODOO_POSTGRES_CPU_REQUEST:-250m}"
export PARAM_ODOO_POSTGRES_CPU_LIMIT="${PARAM_ODOO_POSTGRES_CPU_LIMIT:-500m}"
export PARAM_ODOO_POSTGRES_MEMORY_REQUEST="${PARAM_ODOO_POSTGRES_MEMORY_REQUEST:-256Mi}"
export PARAM_ODOO_POSTGRES_MEMORY_LIMIT="${PARAM_ODOO_POSTGRES_MEMORY_LIMIT:-512Mi}"

# Odoo app
export PARAM_ODOO_CPU_REQUEST="${PARAM_ODOO_CPU_REQUEST:-500m}"
export PARAM_ODOO_CPU_LIMIT="${PARAM_ODOO_CPU_LIMIT:-1500m}"
export PARAM_ODOO_MEMORY_REQUEST="${PARAM_ODOO_MEMORY_REQUEST:-512Mi}"
export PARAM_ODOO_MEMORY_LIMIT="${PARAM_ODOO_MEMORY_LIMIT:-2Gi}"

# --- SSL / HTTPS ---
_needs_value "${PARAM_ODOO_SSL_ENABLED:-}" && PARAM_ODOO_SSL_ENABLED="true"
export PARAM_ODOO_SSL_ENABLED

if [[ "${PARAM_ODOO_SSL_ENABLED}" == "true" ]]; then
    if ! _needs_value "${PARAM_ODOO_HOSTNAME:-}"; then
        PARAM_HOSTNAME="${PARAM_ODOO_HOSTNAME}"
        export PARAM_HOSTNAME
    fi
    ssl_full_setup "odoo" "PARAM_HOSTNAME" "odoo-web" 80
    PARAM_ODOO_HOSTNAME="${SSL_HOSTNAME}"
    export PARAM_ODOO_HOSTNAME
    log_info "[odoo/pre-install] SSL enabled — HTTPS hostname: ${SSL_HOSTNAME}"
else
    log_info "[odoo/pre-install] SSL disabled — access via NodePort only."
fi

log_info "[odoo/pre-install] Pre-install complete."
readonly _ODOO_PRE_INSTALL_DONE=1
export _ODOO_PRE_INSTALL_DONE
