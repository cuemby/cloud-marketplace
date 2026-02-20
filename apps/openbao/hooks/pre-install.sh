#!/usr/bin/env bash
# pre-install.sh — OpenBao pre-install hook.
# Generates dev root token, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_OPENBAO_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/ssl-hooks.sh
source "${BOOTSTRAP_DIR}/lib/ssl-hooks.sh"

log_info "[openbao/pre-install] Setting defaults and generating credentials..."

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
    log_info "[openbao/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Credential generation ---
if _needs_value "${PARAM_OPENBAO_DEV_ROOT_TOKEN:-}"; then
    PARAM_OPENBAO_DEV_ROOT_TOKEN="$(_generate_password)"
    export PARAM_OPENBAO_DEV_ROOT_TOKEN
    log_info "[openbao/pre-install] Generated dev root token."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_OPENBAO_DATA_SIZE:-}" && PARAM_OPENBAO_DATA_SIZE="10Gi"
export PARAM_OPENBAO_DATA_SIZE

# --- NodePort ---
_needs_value "${PARAM_OPENBAO_NODEPORT:-}" && PARAM_OPENBAO_NODEPORT="30820"
export PARAM_OPENBAO_NODEPORT

# --- Resource limits (defaults target a 2-CPU / 4GB VM) ---
export PARAM_OPENBAO_CPU_REQUEST="${PARAM_OPENBAO_CPU_REQUEST:-250m}"
export PARAM_OPENBAO_CPU_LIMIT="${PARAM_OPENBAO_CPU_LIMIT:-2000m}"
export PARAM_OPENBAO_MEMORY_REQUEST="${PARAM_OPENBAO_MEMORY_REQUEST:-512Mi}"
export PARAM_OPENBAO_MEMORY_LIMIT="${PARAM_OPENBAO_MEMORY_LIMIT:-2048Mi}"

# --- SSL / HTTPS ---
_needs_value "${PARAM_OPENBAO_SSL_ENABLED:-}" && PARAM_OPENBAO_SSL_ENABLED="true"
export PARAM_OPENBAO_SSL_ENABLED

if [[ "${PARAM_OPENBAO_SSL_ENABLED}" == "true" ]]; then
    if ! _needs_value "${PARAM_OPENBAO_HOSTNAME:-}"; then
        PARAM_HOSTNAME="${PARAM_OPENBAO_HOSTNAME}"
        export PARAM_HOSTNAME
    fi
    ssl_full_setup "openbao" "PARAM_HOSTNAME" "openbao-http" 80
    PARAM_OPENBAO_HOSTNAME="${SSL_HOSTNAME}"
    export PARAM_OPENBAO_HOSTNAME
    log_info "[openbao/pre-install] SSL enabled — HTTPS hostname: ${SSL_HOSTNAME}"
else
    log_info "[openbao/pre-install] SSL disabled — access via NodePort only."
fi

log_info "[openbao/pre-install] Pre-install complete."
readonly _OPENBAO_PRE_INSTALL_DONE=1
export _OPENBAO_PRE_INSTALL_DONE
