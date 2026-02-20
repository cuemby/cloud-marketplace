#!/usr/bin/env bash
# pre-install.sh — Coolify pre-install hook.
# Installs Docker Engine, generates missing passwords, sets resource defaults,
# and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_COOLIFY_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/ssl-hooks.sh
source "${BOOTSTRAP_DIR}/lib/ssl-hooks.sh"

log_info "[coolify/pre-install] Setting defaults and generating credentials..."

# --- Install Docker Engine (Coolify needs Docker daemon for app management) ---
_install_docker() {
    if command -v docker &>/dev/null; then
        log_info "[coolify/pre-install] Docker already installed."
        return 0
    fi
    log_info "[coolify/pre-install] Installing Docker Engine..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    log_info "[coolify/pre-install] Docker Engine installed and started."
}

_install_docker

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
    log_info "[coolify/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Credential generation ---
if _needs_value "${PARAM_COOLIFY_DB_PASSWORD:-}"; then
    PARAM_COOLIFY_DB_PASSWORD="$(_generate_password)"
    export PARAM_COOLIFY_DB_PASSWORD
    log_info "[coolify/pre-install] Generated PostgreSQL password."
fi

if _needs_value "${PARAM_COOLIFY_REDIS_PASSWORD:-}"; then
    PARAM_COOLIFY_REDIS_PASSWORD="$(_generate_password)"
    export PARAM_COOLIFY_REDIS_PASSWORD
    log_info "[coolify/pre-install] Generated Redis password."
fi

if _needs_value "${PARAM_COOLIFY_APP_KEY:-}"; then
    PARAM_COOLIFY_APP_KEY="base64:$(openssl rand -base64 32)"
    export PARAM_COOLIFY_APP_KEY
    log_info "[coolify/pre-install] Generated Laravel APP_KEY."
fi

if _needs_value "${PARAM_COOLIFY_PUSHER_APP_KEY:-}"; then
    PARAM_COOLIFY_PUSHER_APP_KEY="$(_generate_password)"
    export PARAM_COOLIFY_PUSHER_APP_KEY
    log_info "[coolify/pre-install] Generated Pusher app key."
fi

if _needs_value "${PARAM_COOLIFY_PUSHER_APP_SECRET:-}"; then
    PARAM_COOLIFY_PUSHER_APP_SECRET="$(_generate_password)"
    export PARAM_COOLIFY_PUSHER_APP_SECRET
    log_info "[coolify/pre-install] Generated Pusher app secret."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_COOLIFY_PUSHER_APP_ID:-}" && PARAM_COOLIFY_PUSHER_APP_ID="coolify"
_needs_value "${PARAM_COOLIFY_DB_DATA_SIZE:-}" && PARAM_COOLIFY_DB_DATA_SIZE="10Gi"
_needs_value "${PARAM_COOLIFY_DATA_SIZE:-}" && PARAM_COOLIFY_DATA_SIZE="20Gi"
export PARAM_COOLIFY_PUSHER_APP_ID
export PARAM_COOLIFY_DB_DATA_SIZE
export PARAM_COOLIFY_DATA_SIZE

# --- NodePort ---
export PARAM_COOLIFY_NODEPORT="${PARAM_COOLIFY_NODEPORT:-30800}"

# --- Resource limits (defaults target a 2-CPU / 4GB VM) ---
# PostgreSQL
export PARAM_COOLIFY_POSTGRES_CPU_REQUEST="${PARAM_COOLIFY_POSTGRES_CPU_REQUEST:-250m}"
export PARAM_COOLIFY_POSTGRES_CPU_LIMIT="${PARAM_COOLIFY_POSTGRES_CPU_LIMIT:-500m}"
export PARAM_COOLIFY_POSTGRES_MEMORY_REQUEST="${PARAM_COOLIFY_POSTGRES_MEMORY_REQUEST:-256Mi}"
export PARAM_COOLIFY_POSTGRES_MEMORY_LIMIT="${PARAM_COOLIFY_POSTGRES_MEMORY_LIMIT:-512Mi}"

# Redis
export PARAM_COOLIFY_REDIS_CPU_REQUEST="${PARAM_COOLIFY_REDIS_CPU_REQUEST:-50m}"
export PARAM_COOLIFY_REDIS_CPU_LIMIT="${PARAM_COOLIFY_REDIS_CPU_LIMIT:-250m}"
export PARAM_COOLIFY_REDIS_MEMORY_REQUEST="${PARAM_COOLIFY_REDIS_MEMORY_REQUEST:-64Mi}"
export PARAM_COOLIFY_REDIS_MEMORY_LIMIT="${PARAM_COOLIFY_REDIS_MEMORY_LIMIT:-256Mi}"

# Soketi
export PARAM_COOLIFY_SOKETI_CPU_REQUEST="${PARAM_COOLIFY_SOKETI_CPU_REQUEST:-50m}"
export PARAM_COOLIFY_SOKETI_CPU_LIMIT="${PARAM_COOLIFY_SOKETI_CPU_LIMIT:-250m}"
export PARAM_COOLIFY_SOKETI_MEMORY_REQUEST="${PARAM_COOLIFY_SOKETI_MEMORY_REQUEST:-64Mi}"
export PARAM_COOLIFY_SOKETI_MEMORY_LIMIT="${PARAM_COOLIFY_SOKETI_MEMORY_LIMIT:-256Mi}"

# Coolify app
export PARAM_COOLIFY_CPU_REQUEST="${PARAM_COOLIFY_CPU_REQUEST:-500m}"
export PARAM_COOLIFY_CPU_LIMIT="${PARAM_COOLIFY_CPU_LIMIT:-1500m}"
export PARAM_COOLIFY_MEMORY_REQUEST="${PARAM_COOLIFY_MEMORY_REQUEST:-512Mi}"
export PARAM_COOLIFY_MEMORY_LIMIT="${PARAM_COOLIFY_MEMORY_LIMIT:-2Gi}"

# --- SSL / HTTPS ---
_needs_value "${PARAM_COOLIFY_SSL_ENABLED:-}" && PARAM_COOLIFY_SSL_ENABLED="true"
export PARAM_COOLIFY_SSL_ENABLED

if [[ "${PARAM_COOLIFY_SSL_ENABLED}" == "true" ]]; then
    if ! _needs_value "${PARAM_COOLIFY_HOSTNAME:-}"; then
        PARAM_HOSTNAME="${PARAM_COOLIFY_HOSTNAME}"
        export PARAM_HOSTNAME
    fi
    ssl_full_setup "coolify" "PARAM_HOSTNAME" "coolify-http" 80
    PARAM_COOLIFY_HOSTNAME="${SSL_HOSTNAME}"
    export PARAM_COOLIFY_HOSTNAME
    log_info "[coolify/pre-install] SSL enabled — HTTPS hostname: ${SSL_HOSTNAME}"
else
    log_info "[coolify/pre-install] SSL disabled — access via NodePort only."
fi

log_info "[coolify/pre-install] Pre-install complete."
readonly _COOLIFY_PRE_INSTALL_DONE=1
export _COOLIFY_PRE_INSTALL_DONE
