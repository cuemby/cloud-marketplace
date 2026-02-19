#!/usr/bin/env bash
# pre-install.sh — HAProxy pre-install hook.
# Generates missing stats password, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_HAPROXY_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"

log_info "[haproxy/pre-install] Setting defaults and generating credentials..."

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
    log_info "[haproxy/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Credential generation ---
if _needs_value "${PARAM_HAPROXY_STATS_PASSWORD:-}"; then
    PARAM_HAPROXY_STATS_PASSWORD="$(_generate_password)"
    export PARAM_HAPROXY_STATS_PASSWORD
    log_info "[haproxy/pre-install] Generated stats password."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_HAPROXY_STATS_USER:-}" && PARAM_HAPROXY_STATS_USER="admin"
export PARAM_HAPROXY_STATS_USER

# --- NodePorts ---
_needs_value "${PARAM_HAPROXY_HTTP_NODEPORT:-}" && PARAM_HAPROXY_HTTP_NODEPORT="30080"
export PARAM_HAPROXY_HTTP_NODEPORT

_needs_value "${PARAM_HAPROXY_STATS_NODEPORT:-}" && PARAM_HAPROXY_STATS_NODEPORT="30936"
export PARAM_HAPROXY_STATS_NODEPORT

# --- Resource limits (defaults target a 2-CPU / 2GB VM) ---
export PARAM_HAPROXY_CPU_REQUEST="${PARAM_HAPROXY_CPU_REQUEST:-250m}"
export PARAM_HAPROXY_CPU_LIMIT="${PARAM_HAPROXY_CPU_LIMIT:-2000m}"
export PARAM_HAPROXY_MEMORY_REQUEST="${PARAM_HAPROXY_MEMORY_REQUEST:-256Mi}"
export PARAM_HAPROXY_MEMORY_LIMIT="${PARAM_HAPROXY_MEMORY_LIMIT:-1536Mi}"

log_info "[haproxy/pre-install] Pre-install complete."
readonly _HAPROXY_PRE_INSTALL_DONE=1
export _HAPROXY_PRE_INSTALL_DONE
