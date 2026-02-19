#!/usr/bin/env bash
# pre-install.sh — n8n pre-install hook.
# Generates missing passwords/keys, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_N8N_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"

log_info "[n8n/pre-install] Setting defaults and generating credentials..."

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
    log_info "[n8n/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Credential generation ---
if _needs_value "${PARAM_N8N_DB_PASSWORD:-}"; then
    PARAM_N8N_DB_PASSWORD="$(_generate_password)"
    export PARAM_N8N_DB_PASSWORD
    log_info "[n8n/pre-install] Generated PostgreSQL password."
fi

if _needs_value "${PARAM_N8N_ENCRYPTION_KEY:-}"; then
    PARAM_N8N_ENCRYPTION_KEY="$(_generate_password)"
    export PARAM_N8N_ENCRYPTION_KEY
    log_info "[n8n/pre-install] Generated encryption key."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_N8N_DB_DATA_SIZE:-}" && PARAM_N8N_DB_DATA_SIZE="5Gi"
export PARAM_N8N_DB_DATA_SIZE

_needs_value "${PARAM_N8N_DATA_SIZE:-}" && PARAM_N8N_DATA_SIZE="5Gi"
export PARAM_N8N_DATA_SIZE

# --- NodePort ---
_needs_value "${PARAM_N8N_NODEPORT:-}" && PARAM_N8N_NODEPORT="30080"
export PARAM_N8N_NODEPORT

# --- Resource limits (defaults target a 2-CPU / 4GB VM) ---
# PostgreSQL
export PARAM_N8N_POSTGRES_CPU_REQUEST="${PARAM_N8N_POSTGRES_CPU_REQUEST:-250m}"
export PARAM_N8N_POSTGRES_CPU_LIMIT="${PARAM_N8N_POSTGRES_CPU_LIMIT:-500m}"
export PARAM_N8N_POSTGRES_MEMORY_REQUEST="${PARAM_N8N_POSTGRES_MEMORY_REQUEST:-256Mi}"
export PARAM_N8N_POSTGRES_MEMORY_LIMIT="${PARAM_N8N_POSTGRES_MEMORY_LIMIT:-512Mi}"

# n8n app
export PARAM_N8N_CPU_REQUEST="${PARAM_N8N_CPU_REQUEST:-500m}"
export PARAM_N8N_CPU_LIMIT="${PARAM_N8N_CPU_LIMIT:-1500m}"
export PARAM_N8N_MEMORY_REQUEST="${PARAM_N8N_MEMORY_REQUEST:-512Mi}"
export PARAM_N8N_MEMORY_LIMIT="${PARAM_N8N_MEMORY_LIMIT:-2Gi}"

log_info "[n8n/pre-install] Pre-install complete."
readonly _N8N_PRE_INSTALL_DONE=1
export _N8N_PRE_INSTALL_DONE
