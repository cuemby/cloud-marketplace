#!/usr/bin/env bash
# pre-install.sh — Vaultwarden pre-install hook.
# Generates admin token, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_VAULTWARDEN_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/ssl-hooks.sh
source "${BOOTSTRAP_DIR}/lib/ssl-hooks.sh"

log_info "[vaultwarden/pre-install] Setting defaults and generating credentials..."

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
    log_info "[vaultwarden/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Credential generation ---
if _needs_value "${PARAM_VAULTWARDEN_ADMIN_TOKEN:-}"; then
    PARAM_VAULTWARDEN_ADMIN_TOKEN="$(_generate_password)"
    export PARAM_VAULTWARDEN_ADMIN_TOKEN
    log_info "[vaultwarden/pre-install] Generated Vaultwarden admin token."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_VAULTWARDEN_DATA_SIZE:-}" && PARAM_VAULTWARDEN_DATA_SIZE="5Gi"
export PARAM_VAULTWARDEN_DATA_SIZE

# --- NodePort ---
_needs_value "${PARAM_VAULTWARDEN_NODEPORT:-}" && PARAM_VAULTWARDEN_NODEPORT="30080"
export PARAM_VAULTWARDEN_NODEPORT

# --- Resource limits (defaults target a 2-CPU / 2GB VM) ---
export PARAM_VAULTWARDEN_CPU_REQUEST="${PARAM_VAULTWARDEN_CPU_REQUEST:-250m}"
export PARAM_VAULTWARDEN_CPU_LIMIT="${PARAM_VAULTWARDEN_CPU_LIMIT:-1000m}"
export PARAM_VAULTWARDEN_MEMORY_REQUEST="${PARAM_VAULTWARDEN_MEMORY_REQUEST:-256Mi}"
export PARAM_VAULTWARDEN_MEMORY_LIMIT="${PARAM_VAULTWARDEN_MEMORY_LIMIT:-1536Mi}"

# --- SSL / HTTPS ---
_needs_value "${PARAM_VAULTWARDEN_SSL_ENABLED:-}" && PARAM_VAULTWARDEN_SSL_ENABLED="true"
export PARAM_VAULTWARDEN_SSL_ENABLED

if [[ "${PARAM_VAULTWARDEN_SSL_ENABLED}" == "true" ]]; then
    if ! _needs_value "${PARAM_VAULTWARDEN_HOSTNAME:-}"; then
        PARAM_HOSTNAME="${PARAM_VAULTWARDEN_HOSTNAME}"
        export PARAM_HOSTNAME
    fi
    ssl_full_setup "vaultwarden" "PARAM_HOSTNAME" "vaultwarden-http" 80
    PARAM_VAULTWARDEN_HOSTNAME="${SSL_HOSTNAME}"
    export PARAM_VAULTWARDEN_HOSTNAME
    log_info "[vaultwarden/pre-install] SSL enabled — HTTPS hostname: ${SSL_HOSTNAME}"
else
    log_info "[vaultwarden/pre-install] SSL disabled — access via NodePort only."
fi

log_info "[vaultwarden/pre-install] Pre-install complete."
readonly _VAULTWARDEN_PRE_INSTALL_DONE=1
export _VAULTWARDEN_PRE_INSTALL_DONE
