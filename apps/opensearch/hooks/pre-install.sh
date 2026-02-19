#!/usr/bin/env bash
# pre-install.sh — OpenSearch pre-install hook.
# Generates missing passwords, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_OPENSEARCH_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"

log_info "[opensearch/pre-install] Setting defaults and generating credentials..."

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
    log_info "[opensearch/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

if _needs_value "${PARAM_OPENSEARCH_PASSWORD:-}"; then
    PARAM_OPENSEARCH_PASSWORD="$(_generate_password)"
    export PARAM_OPENSEARCH_PASSWORD
    log_info "[opensearch/pre-install] Generated OpenSearch admin password."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_OPENSEARCH_CLUSTER_NAME:-}" && PARAM_OPENSEARCH_CLUSTER_NAME="opensearch-cluster"
_needs_value "${PARAM_OPENSEARCH_DATA_SIZE:-}" && PARAM_OPENSEARCH_DATA_SIZE="20Gi"
_needs_value "${PARAM_OPENSEARCH_JAVA_OPTS:-}" && PARAM_OPENSEARCH_JAVA_OPTS="-Xms2g -Xmx2g"
export PARAM_OPENSEARCH_CLUSTER_NAME
export PARAM_OPENSEARCH_DATA_SIZE
export PARAM_OPENSEARCH_JAVA_OPTS

# --- NodePort ---
_needs_value "${PARAM_OPENSEARCH_NODEPORT:-}" && PARAM_OPENSEARCH_NODEPORT="30920"
export PARAM_OPENSEARCH_NODEPORT

# --- Resource limits (defaults target a 4-CPU / 8GB VM) ---
export PARAM_OPENSEARCH_CPU_REQUEST="${PARAM_OPENSEARCH_CPU_REQUEST:-1000m}"
export PARAM_OPENSEARCH_CPU_LIMIT="${PARAM_OPENSEARCH_CPU_LIMIT:-4000m}"
export PARAM_OPENSEARCH_MEMORY_REQUEST="${PARAM_OPENSEARCH_MEMORY_REQUEST:-2Gi}"
export PARAM_OPENSEARCH_MEMORY_LIMIT="${PARAM_OPENSEARCH_MEMORY_LIMIT:-6Gi}"

log_info "[opensearch/pre-install] Pre-install complete."
readonly _OPENSEARCH_PRE_INSTALL_DONE=1
export _OPENSEARCH_PRE_INSTALL_DONE
