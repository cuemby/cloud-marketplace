#!/usr/bin/env bash
# pre-install.sh — Kafka pre-install hook.
# Generates cluster ID, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_KAFKA_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"

log_info "[kafka/pre-install] Setting defaults and generating cluster ID..."

# Check if a value is empty or an uninterpolated {{placeholder}}
_needs_value() {
    local val="${1:-}"
    [[ -z "$val" || "$val" == \{\{*\}\} ]]
}

# Clear APP_VERSION if it's an uninterpolated placeholder (use default from app.yaml)
if _needs_value "${APP_VERSION:-}"; then
    unset APP_VERSION
    log_info "[kafka/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Generate KRaft cluster ID ---
if _needs_value "${PARAM_KAFKA_CLUSTER_ID:-}"; then
    PARAM_KAFKA_CLUSTER_ID="$(openssl rand -base64 16 | tr -d '/+=' | head -c 22)"
    export PARAM_KAFKA_CLUSTER_ID
    log_info "[kafka/pre-install] Generated KRaft cluster ID."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_KAFKA_DATA_SIZE:-}" && PARAM_KAFKA_DATA_SIZE="20Gi"
_needs_value "${PARAM_KAFKA_HEAP_OPTS:-}" && PARAM_KAFKA_HEAP_OPTS="-Xms2g -Xmx2g"
export PARAM_KAFKA_DATA_SIZE
export PARAM_KAFKA_HEAP_OPTS

# --- NodePort ---
_needs_value "${PARAM_KAFKA_NODEPORT:-}" && PARAM_KAFKA_NODEPORT="30909"
export PARAM_KAFKA_NODEPORT

# --- Resource limits (defaults target a 4-CPU / 8GB VM) ---
export PARAM_KAFKA_CPU_REQUEST="${PARAM_KAFKA_CPU_REQUEST:-1000m}"
export PARAM_KAFKA_CPU_LIMIT="${PARAM_KAFKA_CPU_LIMIT:-4000m}"
export PARAM_KAFKA_MEMORY_REQUEST="${PARAM_KAFKA_MEMORY_REQUEST:-2Gi}"
export PARAM_KAFKA_MEMORY_LIMIT="${PARAM_KAFKA_MEMORY_LIMIT:-6Gi}"

log_info "[kafka/pre-install] Pre-install complete."
readonly _KAFKA_PRE_INSTALL_DONE=1
export _KAFKA_PRE_INSTALL_DONE
