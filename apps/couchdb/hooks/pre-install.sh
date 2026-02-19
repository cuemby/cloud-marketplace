#!/usr/bin/env bash
# pre-install.sh — CouchDB pre-install hook.
# Generates missing passwords, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_COUCHDB_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"

log_info "[couchdb/pre-install] Setting defaults and generating credentials..."

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
    log_info "[couchdb/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

if _needs_value "${PARAM_COUCHDB_PASSWORD:-}"; then
    PARAM_COUCHDB_PASSWORD="$(_generate_password)"
    export PARAM_COUCHDB_PASSWORD
    log_info "[couchdb/pre-install] Generated CouchDB admin password."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_COUCHDB_USER:-}" && PARAM_COUCHDB_USER="admin"
_needs_value "${PARAM_COUCHDB_DATA_SIZE:-}" && PARAM_COUCHDB_DATA_SIZE="10Gi"
export PARAM_COUCHDB_USER
export PARAM_COUCHDB_DATA_SIZE

# --- NodePort ---
_needs_value "${PARAM_COUCHDB_NODEPORT:-}" && PARAM_COUCHDB_NODEPORT="30594"
export PARAM_COUCHDB_NODEPORT

# --- Resource limits (defaults target a 2-CPU / 4GB VM) ---
export PARAM_COUCHDB_CPU_REQUEST="${PARAM_COUCHDB_CPU_REQUEST:-250m}"
export PARAM_COUCHDB_CPU_LIMIT="${PARAM_COUCHDB_CPU_LIMIT:-1000m}"
export PARAM_COUCHDB_MEMORY_REQUEST="${PARAM_COUCHDB_MEMORY_REQUEST:-512Mi}"
export PARAM_COUCHDB_MEMORY_LIMIT="${PARAM_COUCHDB_MEMORY_LIMIT:-2Gi}"

log_info "[couchdb/pre-install] Pre-install complete."
readonly _COUCHDB_PRE_INSTALL_DONE=1
export _COUCHDB_PRE_INSTALL_DONE
