#!/usr/bin/env bash
# pre-install.sh — Portainer CE pre-install hook.
# Sets resource defaults and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_PORTAINER_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"

log_info "[portainer/pre-install] Setting defaults..."

# Check if a value is empty or an uninterpolated {{placeholder}}
_needs_value() {
    local val="${1:-}"
    [[ -z "$val" || "$val" == \{\{*\}\} ]]
}

# Clear APP_VERSION if it's an uninterpolated placeholder (use default from app.yaml)
if _needs_value "${APP_VERSION:-}"; then
    unset APP_VERSION
    log_info "[portainer/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_PORTAINER_DATA_SIZE:-}" && PARAM_PORTAINER_DATA_SIZE="5Gi"
export PARAM_PORTAINER_DATA_SIZE

# --- NodePort ---
_needs_value "${PARAM_PORTAINER_NODEPORT:-}" && PARAM_PORTAINER_NODEPORT="30900"
export PARAM_PORTAINER_NODEPORT

# --- Resource limits (defaults target a 2-CPU / 2GB VM) ---
export PARAM_PORTAINER_CPU_REQUEST="${PARAM_PORTAINER_CPU_REQUEST:-250m}"
export PARAM_PORTAINER_CPU_LIMIT="${PARAM_PORTAINER_CPU_LIMIT:-2000m}"
export PARAM_PORTAINER_MEMORY_REQUEST="${PARAM_PORTAINER_MEMORY_REQUEST:-256Mi}"
export PARAM_PORTAINER_MEMORY_LIMIT="${PARAM_PORTAINER_MEMORY_LIMIT:-1536Mi}"

log_info "[portainer/pre-install] Pre-install complete."
readonly _PORTAINER_PRE_INSTALL_DONE=1
export _PORTAINER_PRE_INSTALL_DONE
