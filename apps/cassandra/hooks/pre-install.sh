#!/usr/bin/env bash
# pre-install.sh — Cassandra pre-install hook.
# Generates missing passwords, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_CASS_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"

log_info "[cassandra/pre-install] Setting defaults and generating credentials..."

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
    log_info "[cassandra/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

if _needs_value "${PARAM_CASSANDRA_PASSWORD:-}"; then
    PARAM_CASSANDRA_PASSWORD="$(_generate_password)"
    export PARAM_CASSANDRA_PASSWORD
    log_info "[cassandra/pre-install] Generated Cassandra superuser password."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_CASSANDRA_CLUSTER_NAME:-}" && PARAM_CASSANDRA_CLUSTER_NAME="CuembyCassandra"
_needs_value "${PARAM_CASSANDRA_DATA_SIZE:-}" && PARAM_CASSANDRA_DATA_SIZE="20Gi"
_needs_value "${PARAM_CASSANDRA_NUM_TOKENS:-}" && PARAM_CASSANDRA_NUM_TOKENS="256"
export PARAM_CASSANDRA_CLUSTER_NAME
export PARAM_CASSANDRA_DATA_SIZE
export PARAM_CASSANDRA_NUM_TOKENS

# --- JVM heap tuning (paired: MAX_HEAP_SIZE + HEAP_NEWSIZE) ---
_needs_value "${PARAM_CASSANDRA_MAX_HEAP_SIZE:-}" && PARAM_CASSANDRA_MAX_HEAP_SIZE="2G"
_needs_value "${PARAM_CASSANDRA_HEAP_NEWSIZE:-}" && PARAM_CASSANDRA_HEAP_NEWSIZE="512M"
export PARAM_CASSANDRA_MAX_HEAP_SIZE
export PARAM_CASSANDRA_HEAP_NEWSIZE

# --- NodePort ---
_needs_value "${PARAM_CASSANDRA_NODEPORT:-}" && PARAM_CASSANDRA_NODEPORT="30942"
export PARAM_CASSANDRA_NODEPORT

# --- Resource limits (defaults target a 4-CPU / 8GB VM) ---
export PARAM_CASSANDRA_CPU_REQUEST="${PARAM_CASSANDRA_CPU_REQUEST:-1000m}"
export PARAM_CASSANDRA_CPU_LIMIT="${PARAM_CASSANDRA_CPU_LIMIT:-4000m}"
export PARAM_CASSANDRA_MEMORY_REQUEST="${PARAM_CASSANDRA_MEMORY_REQUEST:-2Gi}"
export PARAM_CASSANDRA_MEMORY_LIMIT="${PARAM_CASSANDRA_MEMORY_LIMIT:-6Gi}"

log_info "[cassandra/pre-install] Pre-install complete."
readonly _CASS_PRE_INSTALL_DONE=1
export _CASS_PRE_INSTALL_DONE
