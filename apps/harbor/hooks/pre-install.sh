#!/usr/bin/env bash
# pre-install.sh — Harbor pre-install hook.
# Generates missing passwords, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_HARBOR_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/ssl-hooks.sh
source "${BOOTSTRAP_DIR}/lib/ssl-hooks.sh"

log_info "[harbor/pre-install] Setting defaults and generating credentials..."

# --- Password generation (alphanumeric only to avoid YAML escaping issues) ---
_generate_password() {
    openssl rand -base64 24 | tr -d '/+=' | head -c 32
}

# Generate a 16-character alphanumeric key
_generate_secret_key() {
    openssl rand -base64 24 | tr -d '/+=' | head -c 16
}

# Check if a value is empty or an uninterpolated {{placeholder}}
_needs_value() {
    local val="${1:-}"
    [[ -z "$val" || "$val" == \{\{*\}\} ]]
}

# Clear APP_VERSION if it's an uninterpolated placeholder
if _needs_value "${APP_VERSION:-}"; then
    unset APP_VERSION
    log_info "[harbor/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Credential generation ---
if _needs_value "${PARAM_HARBOR_ADMIN_PASSWORD:-}"; then
    PARAM_HARBOR_ADMIN_PASSWORD="$(_generate_password)"
    export PARAM_HARBOR_ADMIN_PASSWORD
    log_info "[harbor/pre-install] Generated Harbor admin password."
fi

if _needs_value "${PARAM_HARBOR_DB_PASSWORD:-}"; then
    PARAM_HARBOR_DB_PASSWORD="$(_generate_password)"
    export PARAM_HARBOR_DB_PASSWORD
    log_info "[harbor/pre-install] Generated PostgreSQL password."
fi

if _needs_value "${PARAM_HARBOR_SECRET_KEY:-}"; then
    PARAM_HARBOR_SECRET_KEY="$(_generate_secret_key)"
    export PARAM_HARBOR_SECRET_KEY
    log_info "[harbor/pre-install] Generated Harbor secret key (16 chars)."
fi

if _needs_value "${PARAM_HARBOR_VALKEY_PASSWORD:-}"; then
    PARAM_HARBOR_VALKEY_PASSWORD="$(_generate_password)"
    export PARAM_HARBOR_VALKEY_PASSWORD
    log_info "[harbor/pre-install] Generated Valkey password."
fi

# Internal secrets (not user-facing, always generated)
if _needs_value "${PARAM_HARBOR_CORE_SECRET:-}"; then
    PARAM_HARBOR_CORE_SECRET="$(_generate_password)"
    export PARAM_HARBOR_CORE_SECRET
fi

if _needs_value "${PARAM_HARBOR_CSRF_KEY:-}"; then
    PARAM_HARBOR_CSRF_KEY="$(_generate_password)"
    export PARAM_HARBOR_CSRF_KEY
fi

if _needs_value "${PARAM_HARBOR_REGISTRY_HTTP_SECRET:-}"; then
    PARAM_HARBOR_REGISTRY_HTTP_SECRET="$(_generate_password)"
    export PARAM_HARBOR_REGISTRY_HTTP_SECRET
fi

if _needs_value "${PARAM_HARBOR_JOBSERVICE_SECRET:-}"; then
    PARAM_HARBOR_JOBSERVICE_SECRET="$(_generate_password)"
    export PARAM_HARBOR_JOBSERVICE_SECRET
fi

# --- Token auth certificate (core signs JWTs, registry verifies) ---
_harbor_token_cert_dir="$(mktemp -d)"
openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
    -keyout "${_harbor_token_cert_dir}/tls.key" \
    -out "${_harbor_token_cert_dir}/tls.crt" \
    -subj "/CN=harbor-token-service" 2>/dev/null
PARAM_HARBOR_TOKEN_KEY="$(base64 < "${_harbor_token_cert_dir}/tls.key" | tr -d '\n')"
PARAM_HARBOR_TOKEN_CERT="$(base64 < "${_harbor_token_cert_dir}/tls.crt" | tr -d '\n')"
export PARAM_HARBOR_TOKEN_KEY PARAM_HARBOR_TOKEN_CERT
rm -rf "${_harbor_token_cert_dir}"
log_info "[harbor/pre-install] Generated token auth key pair."

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_HARBOR_REGISTRY_DATA_SIZE:-}" && PARAM_HARBOR_REGISTRY_DATA_SIZE="50Gi"
_needs_value "${PARAM_HARBOR_DB_DATA_SIZE:-}" && PARAM_HARBOR_DB_DATA_SIZE="10Gi"
export PARAM_HARBOR_REGISTRY_DATA_SIZE
export PARAM_HARBOR_DB_DATA_SIZE

# --- External URL (defaults to VM IP + NodePort) ---
_needs_value "${PARAM_HARBOR_EXTERNAL_URL:-}" && PARAM_HARBOR_EXTERNAL_URL="localhost:${DEFAULT_HTTPS_NODEPORT}"
export PARAM_HARBOR_EXTERNAL_URL

# --- NodePort ---
export PARAM_HTTPS_NODEPORT="${PARAM_HTTPS_NODEPORT:-${DEFAULT_HTTPS_NODEPORT}}"

# --- Resource limits (defaults target a 4-CPU / 8GB VM) ---
# Harbor DB (PostgreSQL)
export PARAM_HARBOR_DB_CPU_REQUEST="${PARAM_HARBOR_DB_CPU_REQUEST:-250m}"
export PARAM_HARBOR_DB_CPU_LIMIT="${PARAM_HARBOR_DB_CPU_LIMIT:-500m}"
export PARAM_HARBOR_DB_MEMORY_REQUEST="${PARAM_HARBOR_DB_MEMORY_REQUEST:-256Mi}"
export PARAM_HARBOR_DB_MEMORY_LIMIT="${PARAM_HARBOR_DB_MEMORY_LIMIT:-512Mi}"

# Valkey
export PARAM_HARBOR_VALKEY_CPU_REQUEST="${PARAM_HARBOR_VALKEY_CPU_REQUEST:-100m}"
export PARAM_HARBOR_VALKEY_CPU_LIMIT="${PARAM_HARBOR_VALKEY_CPU_LIMIT:-500m}"
export PARAM_HARBOR_VALKEY_MEMORY_REQUEST="${PARAM_HARBOR_VALKEY_MEMORY_REQUEST:-128Mi}"
export PARAM_HARBOR_VALKEY_MEMORY_LIMIT="${PARAM_HARBOR_VALKEY_MEMORY_LIMIT:-512Mi}"

# Harbor Core
export PARAM_HARBOR_CORE_CPU_REQUEST="${PARAM_HARBOR_CORE_CPU_REQUEST:-250m}"
export PARAM_HARBOR_CORE_CPU_LIMIT="${PARAM_HARBOR_CORE_CPU_LIMIT:-1000m}"
export PARAM_HARBOR_CORE_MEMORY_REQUEST="${PARAM_HARBOR_CORE_MEMORY_REQUEST:-256Mi}"
export PARAM_HARBOR_CORE_MEMORY_LIMIT="${PARAM_HARBOR_CORE_MEMORY_LIMIT:-1Gi}"

# Registry
export PARAM_HARBOR_REGISTRY_CPU_REQUEST="${PARAM_HARBOR_REGISTRY_CPU_REQUEST:-250m}"
export PARAM_HARBOR_REGISTRY_CPU_LIMIT="${PARAM_HARBOR_REGISTRY_CPU_LIMIT:-1000m}"
export PARAM_HARBOR_REGISTRY_MEMORY_REQUEST="${PARAM_HARBOR_REGISTRY_MEMORY_REQUEST:-256Mi}"
export PARAM_HARBOR_REGISTRY_MEMORY_LIMIT="${PARAM_HARBOR_REGISTRY_MEMORY_LIMIT:-1Gi}"

# JobService
export PARAM_HARBOR_JOBSERVICE_CPU_REQUEST="${PARAM_HARBOR_JOBSERVICE_CPU_REQUEST:-100m}"
export PARAM_HARBOR_JOBSERVICE_CPU_LIMIT="${PARAM_HARBOR_JOBSERVICE_CPU_LIMIT:-500m}"
export PARAM_HARBOR_JOBSERVICE_MEMORY_REQUEST="${PARAM_HARBOR_JOBSERVICE_MEMORY_REQUEST:-256Mi}"
export PARAM_HARBOR_JOBSERVICE_MEMORY_LIMIT="${PARAM_HARBOR_JOBSERVICE_MEMORY_LIMIT:-512Mi}"

# Portal
export PARAM_HARBOR_PORTAL_CPU_REQUEST="${PARAM_HARBOR_PORTAL_CPU_REQUEST:-100m}"
export PARAM_HARBOR_PORTAL_CPU_LIMIT="${PARAM_HARBOR_PORTAL_CPU_LIMIT:-500m}"
export PARAM_HARBOR_PORTAL_MEMORY_REQUEST="${PARAM_HARBOR_PORTAL_MEMORY_REQUEST:-128Mi}"
export PARAM_HARBOR_PORTAL_MEMORY_LIMIT="${PARAM_HARBOR_PORTAL_MEMORY_LIMIT:-256Mi}"

# Trivy
export PARAM_HARBOR_TRIVY_CPU_REQUEST="${PARAM_HARBOR_TRIVY_CPU_REQUEST:-200m}"
export PARAM_HARBOR_TRIVY_CPU_LIMIT="${PARAM_HARBOR_TRIVY_CPU_LIMIT:-1000m}"
export PARAM_HARBOR_TRIVY_MEMORY_REQUEST="${PARAM_HARBOR_TRIVY_MEMORY_REQUEST:-512Mi}"
export PARAM_HARBOR_TRIVY_MEMORY_LIMIT="${PARAM_HARBOR_TRIVY_MEMORY_LIMIT:-2Gi}"

# --- SSL / HTTPS ---
_needs_value "${PARAM_HARBOR_SSL_ENABLED:-}" && PARAM_HARBOR_SSL_ENABLED="true"
export PARAM_HARBOR_SSL_ENABLED

if [[ "${PARAM_HARBOR_SSL_ENABLED}" == "true" ]]; then
    if ! _needs_value "${PARAM_HARBOR_HOSTNAME:-}"; then
        PARAM_HOSTNAME="${PARAM_HARBOR_HOSTNAME}"
        export PARAM_HOSTNAME
    fi
    ssl_full_setup "harbor" "PARAM_HOSTNAME" "harbor-portal-http" 80
    PARAM_HARBOR_HOSTNAME="${SSL_HOSTNAME}"
    export PARAM_HARBOR_HOSTNAME
    log_info "[harbor/pre-install] SSL enabled — HTTPS hostname: ${SSL_HOSTNAME}"
else
    log_info "[harbor/pre-install] SSL disabled — access via NodePort only."
fi

log_info "[harbor/pre-install] Pre-install complete."
readonly _HARBOR_PRE_INSTALL_DONE=1
export _HARBOR_PRE_INSTALL_DONE
