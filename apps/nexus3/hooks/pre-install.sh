#!/usr/bin/env bash
# pre-install.sh — Nexus3 pre-install hook.
# Sets resource defaults and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_NEXUS_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"

log_info "[nexus3/pre-install] Setting defaults..."

# Check if a value is empty or an uninterpolated {{placeholder}}
_needs_value() {
    local val="${1:-}"
    [[ -z "$val" || "$val" == \{\{*\}\} ]]
}

# Clear APP_VERSION if it's an uninterpolated placeholder (use default from app.yaml)
if _needs_value "${APP_VERSION:-}"; then
    unset APP_VERSION
    log_info "[nexus3/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_NEXUS_DATA_SIZE:-}" && PARAM_NEXUS_DATA_SIZE="50Gi"
export PARAM_NEXUS_DATA_SIZE

# --- NodePort ---
_needs_value "${PARAM_NEXUS_NODEPORT:-}" && PARAM_NEXUS_NODEPORT="30081"
export PARAM_NEXUS_NODEPORT

# --- Resource limits (defaults target a 2-CPU / 4GB VM) ---
export PARAM_NEXUS_CPU_REQUEST="${PARAM_NEXUS_CPU_REQUEST:-250m}"
export PARAM_NEXUS_CPU_LIMIT="${PARAM_NEXUS_CPU_LIMIT:-2000m}"
export PARAM_NEXUS_MEMORY_REQUEST="${PARAM_NEXUS_MEMORY_REQUEST:-512Mi}"
export PARAM_NEXUS_MEMORY_LIMIT="${PARAM_NEXUS_MEMORY_LIMIT:-3072Mi}"

log_info "[nexus3/pre-install] Pre-install complete."
readonly _NEXUS_PRE_INSTALL_DONE=1
export _NEXUS_PRE_INSTALL_DONE
