#!/usr/bin/env bash
# pre-install.sh — Devtron pre-install hook.
# Generates missing passwords, sets resource defaults, and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_DEVTRON_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/ssl-hooks.sh
source "${BOOTSTRAP_DIR}/lib/ssl-hooks.sh"

log_info "[devtron/pre-install] Setting defaults and generating credentials..."

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
    log_info "[devtron/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Credential generation ---
if _needs_value "${PARAM_DEVTRON_DB_PASSWORD:-}"; then
    PARAM_DEVTRON_DB_PASSWORD="$(_generate_password)"
    export PARAM_DEVTRON_DB_PASSWORD
    log_info "[devtron/pre-install] Generated PostgreSQL password."
fi

if _needs_value "${PARAM_DEVTRON_ADMIN_PASSWORD:-}"; then
    PARAM_DEVTRON_ADMIN_PASSWORD="$(_generate_password)"
    export PARAM_DEVTRON_ADMIN_PASSWORD
    log_info "[devtron/pre-install] Generated admin password."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_DEVTRON_DB_DATA_SIZE:-}" && PARAM_DEVTRON_DB_DATA_SIZE="10Gi"
export PARAM_DEVTRON_DB_DATA_SIZE

# --- NodePort defaults ---
_needs_value "${PARAM_DEVTRON_DASHBOARD_NODEPORT:-}" && PARAM_DEVTRON_DASHBOARD_NODEPORT="30080"
export PARAM_DEVTRON_DASHBOARD_NODEPORT

# --- Resource limits (defaults target a 4-CPU / 8GB VM) ---
# PostgreSQL
export PARAM_DEVTRON_POSTGRES_CPU_REQUEST="${PARAM_DEVTRON_POSTGRES_CPU_REQUEST:-250m}"
export PARAM_DEVTRON_POSTGRES_CPU_LIMIT="${PARAM_DEVTRON_POSTGRES_CPU_LIMIT:-500m}"
export PARAM_DEVTRON_POSTGRES_MEMORY_REQUEST="${PARAM_DEVTRON_POSTGRES_MEMORY_REQUEST:-256Mi}"
export PARAM_DEVTRON_POSTGRES_MEMORY_LIMIT="${PARAM_DEVTRON_POSTGRES_MEMORY_LIMIT:-512Mi}"

# NATS
export PARAM_DEVTRON_NATS_CPU_REQUEST="${PARAM_DEVTRON_NATS_CPU_REQUEST:-100m}"
export PARAM_DEVTRON_NATS_CPU_LIMIT="${PARAM_DEVTRON_NATS_CPU_LIMIT:-500m}"
export PARAM_DEVTRON_NATS_MEMORY_REQUEST="${PARAM_DEVTRON_NATS_MEMORY_REQUEST:-128Mi}"
export PARAM_DEVTRON_NATS_MEMORY_LIMIT="${PARAM_DEVTRON_NATS_MEMORY_LIMIT:-1536Mi}"

# Orchestrator (Hyperion)
export PARAM_DEVTRON_ORCHESTRATOR_CPU_REQUEST="${PARAM_DEVTRON_ORCHESTRATOR_CPU_REQUEST:-500m}"
export PARAM_DEVTRON_ORCHESTRATOR_CPU_LIMIT="${PARAM_DEVTRON_ORCHESTRATOR_CPU_LIMIT:-2000m}"
export PARAM_DEVTRON_ORCHESTRATOR_MEMORY_REQUEST="${PARAM_DEVTRON_ORCHESTRATOR_MEMORY_REQUEST:-512Mi}"
export PARAM_DEVTRON_ORCHESTRATOR_MEMORY_LIMIT="${PARAM_DEVTRON_ORCHESTRATOR_MEMORY_LIMIT:-3Gi}"

# Dashboard (UI)
export PARAM_DEVTRON_DASHBOARD_CPU_REQUEST="${PARAM_DEVTRON_DASHBOARD_CPU_REQUEST:-100m}"
export PARAM_DEVTRON_DASHBOARD_CPU_LIMIT="${PARAM_DEVTRON_DASHBOARD_CPU_LIMIT:-500m}"
export PARAM_DEVTRON_DASHBOARD_MEMORY_REQUEST="${PARAM_DEVTRON_DASHBOARD_MEMORY_REQUEST:-128Mi}"
export PARAM_DEVTRON_DASHBOARD_MEMORY_LIMIT="${PARAM_DEVTRON_DASHBOARD_MEMORY_LIMIT:-512Mi}"

# --- Namespace for RBAC (ClusterRoleBinding needs explicit namespace) ---
export PARAM_DEVTRON_NAMESPACE="${HELM_NAMESPACE_PREFIX}devtron"

# --- Create devtroncd namespace + secret (Hyperion binary hardcodes this namespace) ---
log_info "[devtron/pre-install] Creating devtroncd namespace and secret for Hyperion..."
kubectl create namespace devtroncd --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic devtron-secret \
    --namespace=devtroncd \
    --from-literal=PG_PASSWORD="${PARAM_DEVTRON_DB_PASSWORD}" \
    --from-literal=ADMIN_PASSWORD="${PARAM_DEVTRON_ADMIN_PASSWORD}" \
    --from-literal=POSTGRES_PASSWORD="${PARAM_DEVTRON_DB_PASSWORD}" \
    --from-literal=POSTGRES_USER=postgres \
    --from-literal=POSTGRES_DB=orchestrator \
    --dry-run=client -o yaml | kubectl apply -f -

# --- SSL / HTTPS ---
_needs_value "${PARAM_DEVTRON_SSL_ENABLED:-}" && PARAM_DEVTRON_SSL_ENABLED="true"
export PARAM_DEVTRON_SSL_ENABLED

if [[ "${PARAM_DEVTRON_SSL_ENABLED}" == "true" ]]; then
    if ! _needs_value "${PARAM_DEVTRON_HOSTNAME:-}"; then
        PARAM_HOSTNAME="${PARAM_DEVTRON_HOSTNAME}"
        export PARAM_HOSTNAME
    fi
    ssl_full_setup "devtron" "PARAM_HOSTNAME" "devtron-dashboard-http" 80
    PARAM_DEVTRON_HOSTNAME="${SSL_HOSTNAME}"
    export PARAM_DEVTRON_HOSTNAME
    log_info "[devtron/pre-install] SSL enabled — HTTPS hostname: ${SSL_HOSTNAME}"
else
    log_info "[devtron/pre-install] SSL disabled — access via NodePort only."
fi

log_info "[devtron/pre-install] Pre-install complete."
readonly _DEVTRON_PRE_INSTALL_DONE=1
export _DEVTRON_PRE_INSTALL_DONE
