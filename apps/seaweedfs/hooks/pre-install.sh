#!/usr/bin/env bash
set -euo pipefail

[[ -n "${_SEAWEEDFS_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

source "${BOOTSTRAP_DIR}/lib/logging.sh"
source "${BOOTSTRAP_DIR}/lib/constants.sh"

log_info "[seaweedfs/pre-install] Setting defaults..."

_needs_value() {
    local val="${1:-}"
    [[ -z "$val" || "$val" == \{\{*\}\} ]]
}

# Set defaults for optional parameters
if _needs_value "${PARAM_SEAWEEDFS_DATA_SIZE:-}"; then
    PARAM_SEAWEEDFS_DATA_SIZE="50Gi"
fi
export PARAM_SEAWEEDFS_DATA_SIZE

if _needs_value "${PARAM_SEAWEEDFS_VOLUME_SIZE_LIMIT:-}"; then
    PARAM_SEAWEEDFS_VOLUME_SIZE_LIMIT="1000"
fi
export PARAM_SEAWEEDFS_VOLUME_SIZE_LIMIT

# Set NodePorts
_needs_value "${PARAM_SEAWEEDFS_S3_NODEPORT:-}" && PARAM_SEAWEEDFS_S3_NODEPORT="30833"
export PARAM_SEAWEEDFS_S3_NODEPORT
_needs_value "${PARAM_SEAWEEDFS_FILER_NODEPORT:-}" && PARAM_SEAWEEDFS_FILER_NODEPORT="30888"
export PARAM_SEAWEEDFS_FILER_NODEPORT
_needs_value "${PARAM_SEAWEEDFS_MASTER_NODEPORT:-}" && PARAM_SEAWEEDFS_MASTER_NODEPORT="30933"
export PARAM_SEAWEEDFS_MASTER_NODEPORT

# Set resource limits
export PARAM_SEAWEEDFS_CPU_REQUEST="${PARAM_SEAWEEDFS_CPU_REQUEST:-250m}"
export PARAM_SEAWEEDFS_CPU_LIMIT="${PARAM_SEAWEEDFS_CPU_LIMIT:-2000m}"
export PARAM_SEAWEEDFS_MEMORY_REQUEST="${PARAM_SEAWEEDFS_MEMORY_REQUEST:-512Mi}"
export PARAM_SEAWEEDFS_MEMORY_LIMIT="${PARAM_SEAWEEDFS_MEMORY_LIMIT:-3Gi}"

log_info "[seaweedfs/pre-install] Pre-install complete."
readonly _SEAWEEDFS_PRE_INSTALL_DONE=1
export _SEAWEEDFS_PRE_INSTALL_DONE
