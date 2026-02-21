#!/usr/bin/env bash
# pre-install.sh — Rancher pre-install hook.
# Generates missing passwords, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_RANCHER_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/ssl-hooks.sh
source "${BOOTSTRAP_DIR}/lib/ssl-hooks.sh"

log_info "[rancher/pre-install] Setting defaults and generating credentials..."

# --- Namespace (needed for RBAC ClusterRoleBinding) ---
export PARAM_RANCHER_NAMESPACE="${HELM_NAMESPACE_PREFIX}rancher"

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
    log_info "[rancher/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Credential generation ---
if _needs_value "${PARAM_RANCHER_BOOTSTRAP_PASSWORD:-}"; then
    PARAM_RANCHER_BOOTSTRAP_PASSWORD="$(_generate_password)"
    export PARAM_RANCHER_BOOTSTRAP_PASSWORD
    log_info "[rancher/pre-install] Generated bootstrap password."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_RANCHER_DATA_SIZE:-}" && PARAM_RANCHER_DATA_SIZE="20Gi"
export PARAM_RANCHER_DATA_SIZE

# --- NodePorts ---
_needs_value "${PARAM_RANCHER_HTTPS_NODEPORT:-}" && PARAM_RANCHER_HTTPS_NODEPORT="30443"
export PARAM_RANCHER_HTTPS_NODEPORT

_needs_value "${PARAM_RANCHER_HTTP_NODEPORT:-}" && PARAM_RANCHER_HTTP_NODEPORT="30080"
export PARAM_RANCHER_HTTP_NODEPORT

# --- Resource limits (defaults target a 4-CPU / 8GB VM) ---
export PARAM_RANCHER_CPU_REQUEST="${PARAM_RANCHER_CPU_REQUEST:-1000m}"
export PARAM_RANCHER_CPU_LIMIT="${PARAM_RANCHER_CPU_LIMIT:-4000m}"
export PARAM_RANCHER_MEMORY_REQUEST="${PARAM_RANCHER_MEMORY_REQUEST:-2Gi}"
export PARAM_RANCHER_MEMORY_LIMIT="${PARAM_RANCHER_MEMORY_LIMIT:-6Gi}"

# --- SSL / HTTPS ---
_needs_value "${PARAM_RANCHER_SSL_ENABLED:-}" && PARAM_RANCHER_SSL_ENABLED="true"
export PARAM_RANCHER_SSL_ENABLED

if [[ "${PARAM_RANCHER_SSL_ENABLED}" == "true" ]]; then
    if ! _needs_value "${PARAM_RANCHER_HOSTNAME:-}"; then
        PARAM_HOSTNAME="${PARAM_RANCHER_HOSTNAME}"
        export PARAM_HOSTNAME
    fi
    ssl_full_setup "rancher" "PARAM_HOSTNAME" "rancher-http" 80
    PARAM_RANCHER_HOSTNAME="${SSL_HOSTNAME}"
    export PARAM_RANCHER_HOSTNAME
    log_info "[rancher/pre-install] SSL enabled — HTTPS hostname: ${SSL_HOSTNAME}"
else
    log_info "[rancher/pre-install] SSL disabled — access via NodePort only."
fi

log_info "[rancher/pre-install] Pre-install complete."
readonly _RANCHER_PRE_INSTALL_DONE=1
export _RANCHER_PRE_INSTALL_DONE
