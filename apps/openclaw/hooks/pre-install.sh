#!/usr/bin/env bash
# pre-install.sh — OpenClaw pre-install hook.
# Validates required API key, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_OPENCLAW_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/ssl-hooks.sh
source "${BOOTSTRAP_DIR}/lib/ssl-hooks.sh"

log_info "[openclaw/pre-install] Setting defaults and validating parameters..."

# --- Token generation (64-char hex, matches openclaw docker-setup.sh) ---
_generate_token() {
    openssl rand -hex 32
}

# Check if a value is empty or an uninterpolated {{placeholder}}
_needs_value() {
    local val="${1:-}"
    [[ -z "$val" || "$val" == \{\{*\}\} ]]
}

# Clear APP_VERSION if it's an uninterpolated placeholder (use default from app.yaml)
if _needs_value "${APP_VERSION:-}"; then
    unset APP_VERSION
    log_info "[openclaw/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Required parameter: LLM API key ---
if _needs_value "${PARAM_OPENCLAW_API_KEY:-}"; then
    log_fatal "[openclaw/pre-install] PARAM_OPENCLAW_API_KEY is required but not set. Provide an Anthropic or OpenAI API key."
fi
export PARAM_OPENCLAW_API_KEY

# --- Gateway token (auto-generated, required for gateway to start) ---
if _needs_value "${PARAM_OPENCLAW_GATEWAY_TOKEN:-}"; then
    PARAM_OPENCLAW_GATEWAY_TOKEN="$(_generate_token)"
    export PARAM_OPENCLAW_GATEWAY_TOKEN
    log_info "[openclaw/pre-install] Generated gateway authentication token."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_OPENCLAW_LLM_PROVIDER:-}" && PARAM_OPENCLAW_LLM_PROVIDER="anthropic"
_needs_value "${PARAM_OPENCLAW_DATA_SIZE:-}" && PARAM_OPENCLAW_DATA_SIZE="10Gi"
export PARAM_OPENCLAW_LLM_PROVIDER
export PARAM_OPENCLAW_DATA_SIZE

# --- NodePort ---
_needs_value "${PARAM_OPENCLAW_NODEPORT:-}" && PARAM_OPENCLAW_NODEPORT="30789"
export PARAM_OPENCLAW_NODEPORT

# --- Resource limits (defaults target a 2-CPU / 4GB VM) ---
export PARAM_OPENCLAW_CPU_REQUEST="${PARAM_OPENCLAW_CPU_REQUEST:-250m}"
export PARAM_OPENCLAW_CPU_LIMIT="${PARAM_OPENCLAW_CPU_LIMIT:-2000m}"
export PARAM_OPENCLAW_MEMORY_REQUEST="${PARAM_OPENCLAW_MEMORY_REQUEST:-512Mi}"
export PARAM_OPENCLAW_MEMORY_LIMIT="${PARAM_OPENCLAW_MEMORY_LIMIT:-3Gi}"

# --- SSL / HTTPS ---
_needs_value "${PARAM_OPENCLAW_SSL_ENABLED:-}" && PARAM_OPENCLAW_SSL_ENABLED="true"
export PARAM_OPENCLAW_SSL_ENABLED

if [[ "${PARAM_OPENCLAW_SSL_ENABLED}" == "true" ]]; then
    # Use app-specific hostname param if provided, otherwise auto-detect via sslip.io
    if ! _needs_value "${PARAM_OPENCLAW_HOSTNAME:-}"; then
        PARAM_HOSTNAME="${PARAM_OPENCLAW_HOSTNAME}"
        export PARAM_HOSTNAME
    fi

    ssl_full_setup "openclaw" "PARAM_HOSTNAME" "openclaw-http" 80

    # Propagate resolved hostname back to app-specific param
    PARAM_OPENCLAW_HOSTNAME="${SSL_HOSTNAME}"
    export PARAM_OPENCLAW_HOSTNAME
    log_info "[openclaw/pre-install] SSL enabled — HTTPS hostname: ${SSL_HOSTNAME}"
else
    log_info "[openclaw/pre-install] SSL disabled — WebSocket access via NodePort only."
fi

log_info "[openclaw/pre-install] Pre-install complete."
readonly _OPENCLAW_PRE_INSTALL_DONE=1
export _OPENCLAW_PRE_INSTALL_DONE
