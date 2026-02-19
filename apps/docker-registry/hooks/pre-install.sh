#!/usr/bin/env bash
# pre-install.sh — Docker Registry pre-install hook.
# Generates missing HTTP secret, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_REGISTRY_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"

log_info "[docker-registry/pre-install] Setting defaults and generating credentials..."

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
    log_info "[docker-registry/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Credential generation ---
if _needs_value "${PARAM_REGISTRY_HTTP_SECRET:-}"; then
    PARAM_REGISTRY_HTTP_SECRET="$(_generate_password)"
    export PARAM_REGISTRY_HTTP_SECRET
    log_info "[docker-registry/pre-install] Generated registry HTTP secret."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_REGISTRY_DATA_SIZE:-}" && PARAM_REGISTRY_DATA_SIZE="50Gi"
export PARAM_REGISTRY_DATA_SIZE

# --- NodePort ---
_needs_value "${PARAM_REGISTRY_NODEPORT:-}" && PARAM_REGISTRY_NODEPORT="30500"
export PARAM_REGISTRY_NODEPORT

# --- Resource limits (defaults target a 2-CPU / 2GB VM) ---
export PARAM_REGISTRY_CPU_REQUEST="${PARAM_REGISTRY_CPU_REQUEST:-250m}"
export PARAM_REGISTRY_CPU_LIMIT="${PARAM_REGISTRY_CPU_LIMIT:-2000m}"
export PARAM_REGISTRY_MEMORY_REQUEST="${PARAM_REGISTRY_MEMORY_REQUEST:-256Mi}"
export PARAM_REGISTRY_MEMORY_LIMIT="${PARAM_REGISTRY_MEMORY_LIMIT:-1536Mi}"

log_info "[docker-registry/pre-install] Pre-install complete."
readonly _REGISTRY_PRE_INSTALL_DONE=1
export _REGISTRY_PRE_INSTALL_DONE
