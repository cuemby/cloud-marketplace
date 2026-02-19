#!/usr/bin/env bash
# pre-install.sh — Gitea pre-install hook.
# Sets resource defaults and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_GITEA_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"

log_info "[gitea/pre-install] Setting defaults..."

# Check if a value is empty or an uninterpolated {{placeholder}}
_needs_value() {
    local val="${1:-}"
    [[ -z "$val" || "$val" == \{\{*\}\} ]]
}

# Clear APP_VERSION if it's an uninterpolated placeholder (use default from app.yaml)
if _needs_value "${APP_VERSION:-}"; then
    unset APP_VERSION
    log_info "[gitea/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_GITEA_DATA_SIZE:-}" && PARAM_GITEA_DATA_SIZE="20Gi"
export PARAM_GITEA_DATA_SIZE

# --- NodePorts ---
_needs_value "${PARAM_GITEA_HTTP_NODEPORT:-}" && PARAM_GITEA_HTTP_NODEPORT="30300"
_needs_value "${PARAM_GITEA_SSH_NODEPORT:-}" && PARAM_GITEA_SSH_NODEPORT="30022"
export PARAM_GITEA_HTTP_NODEPORT
export PARAM_GITEA_SSH_NODEPORT

# --- Resource limits (defaults target a 2-CPU / 4GB VM) ---
export PARAM_GITEA_CPU_REQUEST="${PARAM_GITEA_CPU_REQUEST:-250m}"
export PARAM_GITEA_CPU_LIMIT="${PARAM_GITEA_CPU_LIMIT:-1000m}"
export PARAM_GITEA_MEMORY_REQUEST="${PARAM_GITEA_MEMORY_REQUEST:-256Mi}"
export PARAM_GITEA_MEMORY_LIMIT="${PARAM_GITEA_MEMORY_LIMIT:-2Gi}"

log_info "[gitea/pre-install] Pre-install complete."
readonly _GITEA_PRE_INSTALL_DONE=1
export _GITEA_PRE_INSTALL_DONE
