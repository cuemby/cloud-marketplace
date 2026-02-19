#!/usr/bin/env bash
# pre-install.sh — Percona Server for MySQL pre-install hook.
# Generates missing passwords, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_PERCONA_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"

log_info "[percona-mysql/pre-install] Setting defaults and generating credentials..."

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
    log_info "[percona-mysql/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Credential generation ---
if _needs_value "${PARAM_PERCONA_ROOT_PASSWORD:-}"; then
    PARAM_PERCONA_ROOT_PASSWORD="$(_generate_password)"
    export PARAM_PERCONA_ROOT_PASSWORD
    log_info "[percona-mysql/pre-install] Generated Percona root password."
fi

if _needs_value "${PARAM_PERCONA_PASSWORD:-}"; then
    PARAM_PERCONA_PASSWORD="$(_generate_password)"
    export PARAM_PERCONA_PASSWORD
    log_info "[percona-mysql/pre-install] Generated Percona user password."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_PERCONA_USER:-}" && PARAM_PERCONA_USER="percona"
_needs_value "${PARAM_PERCONA_DATABASE:-}" && PARAM_PERCONA_DATABASE="percona"
_needs_value "${PARAM_PERCONA_DATA_SIZE:-}" && PARAM_PERCONA_DATA_SIZE="10Gi"
export PARAM_PERCONA_USER
export PARAM_PERCONA_DATABASE
export PARAM_PERCONA_DATA_SIZE

# --- NodePort ---
_needs_value "${PARAM_PERCONA_NODEPORT:-}" && PARAM_PERCONA_NODEPORT="30306"
export PARAM_PERCONA_NODEPORT

# --- Resource limits (defaults target a 2-CPU / 4GB VM) ---
export PARAM_PERCONA_CPU_REQUEST="${PARAM_PERCONA_CPU_REQUEST:-250m}"
export PARAM_PERCONA_CPU_LIMIT="${PARAM_PERCONA_CPU_LIMIT:-2000m}"
export PARAM_PERCONA_MEMORY_REQUEST="${PARAM_PERCONA_MEMORY_REQUEST:-512Mi}"
export PARAM_PERCONA_MEMORY_LIMIT="${PARAM_PERCONA_MEMORY_LIMIT:-2Gi}"

log_info "[percona-mysql/pre-install] Pre-install complete."
readonly _PERCONA_PRE_INSTALL_DONE=1
export _PERCONA_PRE_INSTALL_DONE
