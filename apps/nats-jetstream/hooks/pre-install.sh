#!/usr/bin/env bash
# pre-install.sh — NATS JetStream pre-install hook.
# Generates missing auth token, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_NATS_JETSTREAM_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"

log_info "[nats-jetstream/pre-install] Setting defaults and generating credentials..."

# --- Token generation (alphanumeric only to avoid YAML escaping issues) ---
_generate_token() {
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
    log_info "[nats-jetstream/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Credential generation ---
if _needs_value "${PARAM_NATS_AUTH_TOKEN:-}"; then
    PARAM_NATS_AUTH_TOKEN="$(_generate_token)"
    export PARAM_NATS_AUTH_TOKEN
    log_info "[nats-jetstream/pre-install] Generated NATS auth token."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_NATS_DATA_SIZE:-}" && PARAM_NATS_DATA_SIZE="10Gi"
export PARAM_NATS_DATA_SIZE

# --- NodePorts ---
_needs_value "${PARAM_NATS_CLIENT_NODEPORT:-}" && PARAM_NATS_CLIENT_NODEPORT="30422"
_needs_value "${PARAM_NATS_MONITORING_NODEPORT:-}" && PARAM_NATS_MONITORING_NODEPORT="30822"
export PARAM_NATS_CLIENT_NODEPORT
export PARAM_NATS_MONITORING_NODEPORT

# --- Resource limits (defaults target a 2-CPU / 4GB VM) ---
export PARAM_NATS_CPU_REQUEST="${PARAM_NATS_CPU_REQUEST:-250m}"
export PARAM_NATS_CPU_LIMIT="${PARAM_NATS_CPU_LIMIT:-2000m}"
export PARAM_NATS_MEMORY_REQUEST="${PARAM_NATS_MEMORY_REQUEST:-512Mi}"
export PARAM_NATS_MEMORY_LIMIT="${PARAM_NATS_MEMORY_LIMIT:-2Gi}"

log_info "[nats-jetstream/pre-install] Pre-install complete."
readonly _NATS_JETSTREAM_PRE_INSTALL_DONE=1
export _NATS_JETSTREAM_PRE_INSTALL_DONE
