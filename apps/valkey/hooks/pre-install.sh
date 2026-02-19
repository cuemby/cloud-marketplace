#!/usr/bin/env bash
# pre-install.sh — Valkey pre-install hook.
# Generates missing password, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_VALKEY_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"

log_info "[valkey/pre-install] Setting defaults and generating credentials..."

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
    log_info "[valkey/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Credential generation ---
if _needs_value "${PARAM_VALKEY_PASSWORD:-}"; then
    PARAM_VALKEY_PASSWORD="$(_generate_password)"
    export PARAM_VALKEY_PASSWORD
    log_info "[valkey/pre-install] Generated Valkey password."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_VALKEY_DATA_SIZE:-}" && PARAM_VALKEY_DATA_SIZE="5Gi"
_needs_value "${PARAM_VALKEY_MAXMEMORY:-}" && PARAM_VALKEY_MAXMEMORY="1gb"
_needs_value "${PARAM_VALKEY_MAXMEMORY_POLICY:-}" && PARAM_VALKEY_MAXMEMORY_POLICY="allkeys-lru"
export PARAM_VALKEY_DATA_SIZE
export PARAM_VALKEY_MAXMEMORY
export PARAM_VALKEY_MAXMEMORY_POLICY

# --- NodePort ---
_needs_value "${PARAM_VALKEY_NODEPORT:-}" && PARAM_VALKEY_NODEPORT="30379"
export PARAM_VALKEY_NODEPORT

# --- Resource limits (defaults target a 2-CPU / 4GB VM) ---
export PARAM_VALKEY_CPU_REQUEST="${PARAM_VALKEY_CPU_REQUEST:-250m}"
export PARAM_VALKEY_CPU_LIMIT="${PARAM_VALKEY_CPU_LIMIT:-2000m}"
export PARAM_VALKEY_MEMORY_REQUEST="${PARAM_VALKEY_MEMORY_REQUEST:-256Mi}"
export PARAM_VALKEY_MEMORY_LIMIT="${PARAM_VALKEY_MEMORY_LIMIT:-2Gi}"

log_info "[valkey/pre-install] Pre-install complete."
readonly _VALKEY_PRE_INSTALL_DONE=1
export _VALKEY_PRE_INSTALL_DONE
