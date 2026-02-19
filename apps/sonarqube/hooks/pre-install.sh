#!/usr/bin/env bash
# pre-install.sh — SonarQube pre-install hook.
# Generates missing passwords, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_SONARQUBE_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"

log_info "[sonarqube/pre-install] Setting defaults and generating credentials..."

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
    log_info "[sonarqube/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Credential generation ---
if _needs_value "${PARAM_SONARQUBE_DB_PASSWORD:-}"; then
    PARAM_SONARQUBE_DB_PASSWORD="$(_generate_password)"
    export PARAM_SONARQUBE_DB_PASSWORD
    log_info "[sonarqube/pre-install] Generated PostgreSQL password."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_SONARQUBE_DB_DATA_SIZE:-}" && PARAM_SONARQUBE_DB_DATA_SIZE="10Gi"
export PARAM_SONARQUBE_DB_DATA_SIZE

_needs_value "${PARAM_SONARQUBE_DATA_SIZE:-}" && PARAM_SONARQUBE_DATA_SIZE="20Gi"
export PARAM_SONARQUBE_DATA_SIZE

# --- NodePort ---
_needs_value "${PARAM_SONARQUBE_NODEPORT:-}" && PARAM_SONARQUBE_NODEPORT="30900"
export PARAM_SONARQUBE_NODEPORT

# --- Resource limits (defaults target a 4-CPU / 8GB VM) ---
# PostgreSQL
export PARAM_SONARQUBE_POSTGRES_CPU_REQUEST="${PARAM_SONARQUBE_POSTGRES_CPU_REQUEST:-250m}"
export PARAM_SONARQUBE_POSTGRES_CPU_LIMIT="${PARAM_SONARQUBE_POSTGRES_CPU_LIMIT:-500m}"
export PARAM_SONARQUBE_POSTGRES_MEMORY_REQUEST="${PARAM_SONARQUBE_POSTGRES_MEMORY_REQUEST:-256Mi}"
export PARAM_SONARQUBE_POSTGRES_MEMORY_LIMIT="${PARAM_SONARQUBE_POSTGRES_MEMORY_LIMIT:-512Mi}"

# SonarQube app (JVM-based, needs more memory)
export PARAM_SONARQUBE_CPU_REQUEST="${PARAM_SONARQUBE_CPU_REQUEST:-1000m}"
export PARAM_SONARQUBE_CPU_LIMIT="${PARAM_SONARQUBE_CPU_LIMIT:-3000m}"
export PARAM_SONARQUBE_MEMORY_REQUEST="${PARAM_SONARQUBE_MEMORY_REQUEST:-2Gi}"
export PARAM_SONARQUBE_MEMORY_LIMIT="${PARAM_SONARQUBE_MEMORY_LIMIT:-6Gi}"

log_info "[sonarqube/pre-install] Pre-install complete."
readonly _SONARQUBE_PRE_INSTALL_DONE=1
export _SONARQUBE_PRE_INSTALL_DONE
