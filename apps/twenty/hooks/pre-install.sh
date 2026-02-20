#!/usr/bin/env bash
# pre-install.sh — Twenty CRM pre-install hook.
# Generates missing passwords, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_TWENTY_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/ssl-hooks.sh
source "${BOOTSTRAP_DIR}/lib/ssl-hooks.sh"

log_info "[twenty/pre-install] Setting defaults and generating credentials..."

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
    log_info "[twenty/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Credential generation ---
if _needs_value "${PARAM_TWENTY_APP_SECRET:-}"; then
    PARAM_TWENTY_APP_SECRET="$(openssl rand -base64 32)"
    export PARAM_TWENTY_APP_SECRET
    log_info "[twenty/pre-install] Generated app secret."
fi

if _needs_value "${PARAM_TWENTY_DB_PASSWORD:-}"; then
    PARAM_TWENTY_DB_PASSWORD="$(_generate_password)"
    export PARAM_TWENTY_DB_PASSWORD
    log_info "[twenty/pre-install] Generated PostgreSQL password."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_TWENTY_DB_DATA_SIZE:-}" && PARAM_TWENTY_DB_DATA_SIZE="10Gi"
_needs_value "${PARAM_TWENTY_DATA_SIZE:-}" && PARAM_TWENTY_DATA_SIZE="10Gi"
export PARAM_TWENTY_DB_DATA_SIZE
export PARAM_TWENTY_DATA_SIZE

# --- NodePort ---
export PARAM_HTTP_NODEPORT="${PARAM_HTTP_NODEPORT:-${DEFAULT_HTTP_NODEPORT}}"

# --- Resource limits (defaults target a 2-CPU / 4GB VM) ---
export PARAM_TWENTY_POSTGRES_CPU_REQUEST="${PARAM_TWENTY_POSTGRES_CPU_REQUEST:-250m}"
export PARAM_TWENTY_POSTGRES_CPU_LIMIT="${PARAM_TWENTY_POSTGRES_CPU_LIMIT:-1000m}"
export PARAM_TWENTY_POSTGRES_MEMORY_REQUEST="${PARAM_TWENTY_POSTGRES_MEMORY_REQUEST:-512Mi}"
export PARAM_TWENTY_POSTGRES_MEMORY_LIMIT="${PARAM_TWENTY_POSTGRES_MEMORY_LIMIT:-1Gi}"

export PARAM_TWENTY_REDIS_CPU_REQUEST="${PARAM_TWENTY_REDIS_CPU_REQUEST:-100m}"
export PARAM_TWENTY_REDIS_CPU_LIMIT="${PARAM_TWENTY_REDIS_CPU_LIMIT:-500m}"
export PARAM_TWENTY_REDIS_MEMORY_REQUEST="${PARAM_TWENTY_REDIS_MEMORY_REQUEST:-128Mi}"
export PARAM_TWENTY_REDIS_MEMORY_LIMIT="${PARAM_TWENTY_REDIS_MEMORY_LIMIT:-512Mi}"

export PARAM_TWENTY_CPU_REQUEST="${PARAM_TWENTY_CPU_REQUEST:-250m}"
export PARAM_TWENTY_CPU_LIMIT="${PARAM_TWENTY_CPU_LIMIT:-1500m}"
export PARAM_TWENTY_MEMORY_REQUEST="${PARAM_TWENTY_MEMORY_REQUEST:-512Mi}"
export PARAM_TWENTY_MEMORY_LIMIT="${PARAM_TWENTY_MEMORY_LIMIT:-2Gi}"

# --- SSL / HTTPS ---
_needs_value "${PARAM_TWENTY_SSL_ENABLED:-}" && PARAM_TWENTY_SSL_ENABLED="true"
export PARAM_TWENTY_SSL_ENABLED

if [[ "${PARAM_TWENTY_SSL_ENABLED}" == "true" ]]; then
    if ! _needs_value "${PARAM_TWENTY_HOSTNAME:-}"; then
        PARAM_HOSTNAME="${PARAM_TWENTY_HOSTNAME}"
        export PARAM_HOSTNAME
    fi
    ssl_full_setup "twenty" "PARAM_HOSTNAME" "twenty-http" 80
    PARAM_TWENTY_HOSTNAME="${SSL_HOSTNAME}"
    export PARAM_TWENTY_HOSTNAME
    log_info "[twenty/pre-install] SSL enabled — HTTPS hostname: ${SSL_HOSTNAME}"
else
    log_info "[twenty/pre-install] SSL disabled — access via NodePort only."
fi

log_info "[twenty/pre-install] Pre-install complete."
readonly _TWENTY_PRE_INSTALL_DONE=1
export _TWENTY_PRE_INSTALL_DONE
