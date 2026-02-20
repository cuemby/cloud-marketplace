#!/usr/bin/env bash
# pre-install.sh — RabbitMQ pre-install hook.
# Generates missing passwords, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_RABBITMQ_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/ssl-hooks.sh
source "${BOOTSTRAP_DIR}/lib/ssl-hooks.sh"

log_info "[rabbitmq/pre-install] Setting defaults and generating credentials..."

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
    log_info "[rabbitmq/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Credential generation ---
if _needs_value "${PARAM_RABBITMQ_DEFAULT_PASS:-}"; then
    PARAM_RABBITMQ_DEFAULT_PASS="$(_generate_password)"
    export PARAM_RABBITMQ_DEFAULT_PASS
    log_info "[rabbitmq/pre-install] Generated RabbitMQ admin password."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_RABBITMQ_DEFAULT_USER:-}" && PARAM_RABBITMQ_DEFAULT_USER="admin"
_needs_value "${PARAM_RABBITMQ_DATA_SIZE:-}" && PARAM_RABBITMQ_DATA_SIZE="10Gi"
export PARAM_RABBITMQ_DEFAULT_USER
export PARAM_RABBITMQ_DATA_SIZE

# --- NodePorts ---
_needs_value "${PARAM_RABBITMQ_AMQP_NODEPORT:-}" && PARAM_RABBITMQ_AMQP_NODEPORT="30672"
_needs_value "${PARAM_RABBITMQ_MANAGEMENT_NODEPORT:-}" && PARAM_RABBITMQ_MANAGEMENT_NODEPORT="31672"
export PARAM_RABBITMQ_AMQP_NODEPORT
export PARAM_RABBITMQ_MANAGEMENT_NODEPORT

# --- Resource limits (defaults target a 2-CPU / 4GB VM) ---
export PARAM_RABBITMQ_CPU_REQUEST="${PARAM_RABBITMQ_CPU_REQUEST:-250m}"
export PARAM_RABBITMQ_CPU_LIMIT="${PARAM_RABBITMQ_CPU_LIMIT:-2000m}"
export PARAM_RABBITMQ_MEMORY_REQUEST="${PARAM_RABBITMQ_MEMORY_REQUEST:-512Mi}"
export PARAM_RABBITMQ_MEMORY_LIMIT="${PARAM_RABBITMQ_MEMORY_LIMIT:-2Gi}"

# --- SSL / HTTPS ---
_needs_value "${PARAM_RABBITMQ_SSL_ENABLED:-}" && PARAM_RABBITMQ_SSL_ENABLED="true"
export PARAM_RABBITMQ_SSL_ENABLED

if [[ "${PARAM_RABBITMQ_SSL_ENABLED}" == "true" ]]; then
    if ! _needs_value "${PARAM_RABBITMQ_HOSTNAME:-}"; then
        PARAM_HOSTNAME="${PARAM_RABBITMQ_HOSTNAME}"
        export PARAM_HOSTNAME
    fi
    ssl_full_setup "rabbitmq" "PARAM_HOSTNAME" "rabbitmq-web" 80
    PARAM_RABBITMQ_HOSTNAME="${SSL_HOSTNAME}"
    export PARAM_RABBITMQ_HOSTNAME
    log_info "[rabbitmq/pre-install] SSL enabled — HTTPS hostname: ${SSL_HOSTNAME}"
else
    log_info "[rabbitmq/pre-install] SSL disabled — access via NodePort only."
fi

log_info "[rabbitmq/pre-install] Pre-install complete."
readonly _RABBITMQ_PRE_INSTALL_DONE=1
export _RABBITMQ_PRE_INSTALL_DONE
