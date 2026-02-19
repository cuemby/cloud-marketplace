#!/usr/bin/env bash
# pre-install.sh — Keycloak pre-install hook.
# Generates missing passwords, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_KEYCLOAK_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"

log_info "[keycloak/pre-install] Setting defaults and generating credentials..."

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
    log_info "[keycloak/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Credential generation ---
if _needs_value "${PARAM_KEYCLOAK_ADMIN_PASSWORD:-}"; then
    PARAM_KEYCLOAK_ADMIN_PASSWORD="$(_generate_password)"
    export PARAM_KEYCLOAK_ADMIN_PASSWORD
    log_info "[keycloak/pre-install] Generated Keycloak admin password."
fi

if _needs_value "${PARAM_KEYCLOAK_DB_PASSWORD:-}"; then
    PARAM_KEYCLOAK_DB_PASSWORD="$(_generate_password)"
    export PARAM_KEYCLOAK_DB_PASSWORD
    log_info "[keycloak/pre-install] Generated PostgreSQL password."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_KEYCLOAK_ADMIN_USER:-}" && PARAM_KEYCLOAK_ADMIN_USER="admin"
_needs_value "${PARAM_KEYCLOAK_DB_DATA_SIZE:-}" && PARAM_KEYCLOAK_DB_DATA_SIZE="5Gi"
_needs_value "${PARAM_KEYCLOAK_DATA_SIZE:-}" && PARAM_KEYCLOAK_DATA_SIZE="1Gi"
export PARAM_KEYCLOAK_ADMIN_USER
export PARAM_KEYCLOAK_DB_DATA_SIZE
export PARAM_KEYCLOAK_DATA_SIZE

# --- NodePort ---
_needs_value "${PARAM_KEYCLOAK_NODEPORT:-}" && PARAM_KEYCLOAK_NODEPORT="30808"
export PARAM_KEYCLOAK_NODEPORT

# --- Resource limits (defaults target a 2-CPU / 4GB VM) ---
# PostgreSQL
export PARAM_KEYCLOAK_POSTGRES_CPU_REQUEST="${PARAM_KEYCLOAK_POSTGRES_CPU_REQUEST:-250m}"
export PARAM_KEYCLOAK_POSTGRES_CPU_LIMIT="${PARAM_KEYCLOAK_POSTGRES_CPU_LIMIT:-500m}"
export PARAM_KEYCLOAK_POSTGRES_MEMORY_REQUEST="${PARAM_KEYCLOAK_POSTGRES_MEMORY_REQUEST:-256Mi}"
export PARAM_KEYCLOAK_POSTGRES_MEMORY_LIMIT="${PARAM_KEYCLOAK_POSTGRES_MEMORY_LIMIT:-512Mi}"

# Keycloak app
export PARAM_KEYCLOAK_CPU_REQUEST="${PARAM_KEYCLOAK_CPU_REQUEST:-500m}"
export PARAM_KEYCLOAK_CPU_LIMIT="${PARAM_KEYCLOAK_CPU_LIMIT:-1500m}"
export PARAM_KEYCLOAK_MEMORY_REQUEST="${PARAM_KEYCLOAK_MEMORY_REQUEST:-512Mi}"
export PARAM_KEYCLOAK_MEMORY_LIMIT="${PARAM_KEYCLOAK_MEMORY_LIMIT:-2Gi}"

log_info "[keycloak/pre-install] Pre-install complete."
readonly _KEYCLOAK_PRE_INSTALL_DONE=1
export _KEYCLOAK_PRE_INSTALL_DONE
