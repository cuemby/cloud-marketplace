#!/usr/bin/env bash
# pre-install.sh — PostgreSQL pre-install hook.
# Generates missing passwords, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_PG_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"

log_info "[postgresql/pre-install] Setting defaults and generating credentials..."

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
    log_info "[postgresql/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

if _needs_value "${PARAM_POSTGRES_PASSWORD:-}"; then
    PARAM_POSTGRES_PASSWORD="$(_generate_password)"
    export PARAM_POSTGRES_PASSWORD
    log_info "[postgresql/pre-install] Generated PostgreSQL superuser password."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_POSTGRES_USER:-}" && PARAM_POSTGRES_USER="postgres"
_needs_value "${PARAM_POSTGRES_DB:-}" && PARAM_POSTGRES_DB="postgres"
_needs_value "${PARAM_POSTGRESQL_DATA_SIZE:-}" && PARAM_POSTGRESQL_DATA_SIZE="10Gi"
export PARAM_POSTGRES_USER
export PARAM_POSTGRES_DB
export PARAM_POSTGRESQL_DATA_SIZE

# --- Tuning defaults ---
_needs_value "${PARAM_POSTGRESQL_MAX_CONNECTIONS:-}" && PARAM_POSTGRESQL_MAX_CONNECTIONS="100"
_needs_value "${PARAM_POSTGRESQL_SHARED_BUFFERS:-}" && PARAM_POSTGRESQL_SHARED_BUFFERS="256MB"
_needs_value "${PARAM_POSTGRESQL_WORK_MEM:-}" && PARAM_POSTGRESQL_WORK_MEM="4MB"
export PARAM_POSTGRESQL_MAX_CONNECTIONS
export PARAM_POSTGRESQL_SHARED_BUFFERS
export PARAM_POSTGRESQL_WORK_MEM

# --- NodePort ---
_needs_value "${PARAM_POSTGRESQL_NODEPORT:-}" && PARAM_POSTGRESQL_NODEPORT="30432"
export PARAM_POSTGRESQL_NODEPORT

# --- Resource limits (defaults target a 2-CPU / 4GB VM) ---
export PARAM_POSTGRESQL_CPU_REQUEST="${PARAM_POSTGRESQL_CPU_REQUEST:-250m}"
export PARAM_POSTGRESQL_CPU_LIMIT="${PARAM_POSTGRESQL_CPU_LIMIT:-2000m}"
export PARAM_POSTGRESQL_MEMORY_REQUEST="${PARAM_POSTGRESQL_MEMORY_REQUEST:-512Mi}"
export PARAM_POSTGRESQL_MEMORY_LIMIT="${PARAM_POSTGRESQL_MEMORY_LIMIT:-2Gi}"

log_info "[postgresql/pre-install] Pre-install complete."
readonly _PG_PRE_INSTALL_DONE=1
export _PG_PRE_INSTALL_DONE
