#!/usr/bin/env bash
# pre-install.sh — Selenium Grid pre-install hook.
# Sets parameter defaults and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_SELENIUM_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"

log_info "[selenium/pre-install] Setting defaults..."

# Check if a value is empty or an uninterpolated {{placeholder}}
_needs_value() {
    local val="${1:-}"
    [[ -z "$val" || "$val" == \{\{*\}\} ]]
}

# Clear APP_VERSION if it's an uninterpolated placeholder (use default from app.yaml)
if _needs_value "${APP_VERSION:-}"; then
    unset APP_VERSION
    log_info "[selenium/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_SELENIUM_CHROME_NODES:-}" && PARAM_SELENIUM_CHROME_NODES="1"
export PARAM_SELENIUM_CHROME_NODES

_needs_value "${PARAM_SELENIUM_FIREFOX_NODES:-}" && PARAM_SELENIUM_FIREFOX_NODES="1"
export PARAM_SELENIUM_FIREFOX_NODES

# --- NodePorts ---
_needs_value "${PARAM_SELENIUM_HUB_NODEPORT:-}" && PARAM_SELENIUM_HUB_NODEPORT="30444"
export PARAM_SELENIUM_HUB_NODEPORT

# --- Resource limits (defaults target a 4-CPU / 8GB VM) ---
# Hub
export PARAM_SELENIUM_HUB_CPU_REQUEST="${PARAM_SELENIUM_HUB_CPU_REQUEST:-250m}"
export PARAM_SELENIUM_HUB_CPU_LIMIT="${PARAM_SELENIUM_HUB_CPU_LIMIT:-1000m}"
export PARAM_SELENIUM_HUB_MEMORY_REQUEST="${PARAM_SELENIUM_HUB_MEMORY_REQUEST:-512Mi}"
export PARAM_SELENIUM_HUB_MEMORY_LIMIT="${PARAM_SELENIUM_HUB_MEMORY_LIMIT:-1Gi}"

# Chrome Node
export PARAM_SELENIUM_CHROME_CPU_REQUEST="${PARAM_SELENIUM_CHROME_CPU_REQUEST:-500m}"
export PARAM_SELENIUM_CHROME_CPU_LIMIT="${PARAM_SELENIUM_CHROME_CPU_LIMIT:-1500m}"
export PARAM_SELENIUM_CHROME_MEMORY_REQUEST="${PARAM_SELENIUM_CHROME_MEMORY_REQUEST:-1Gi}"
export PARAM_SELENIUM_CHROME_MEMORY_LIMIT="${PARAM_SELENIUM_CHROME_MEMORY_LIMIT:-3Gi}"

# Firefox Node
export PARAM_SELENIUM_FIREFOX_CPU_REQUEST="${PARAM_SELENIUM_FIREFOX_CPU_REQUEST:-500m}"
export PARAM_SELENIUM_FIREFOX_CPU_LIMIT="${PARAM_SELENIUM_FIREFOX_CPU_LIMIT:-1500m}"
export PARAM_SELENIUM_FIREFOX_MEMORY_REQUEST="${PARAM_SELENIUM_FIREFOX_MEMORY_REQUEST:-1Gi}"
export PARAM_SELENIUM_FIREFOX_MEMORY_LIMIT="${PARAM_SELENIUM_FIREFOX_MEMORY_LIMIT:-3Gi}"

log_info "[selenium/pre-install] Pre-install complete."
readonly _SELENIUM_PRE_INSTALL_DONE=1
export _SELENIUM_PRE_INSTALL_DONE
