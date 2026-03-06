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

# Check if a password value needs regeneration (empty, placeholder, or too short)
_needs_password() {
    local val="${1:-}"
    _needs_value "$val" || [[ ${#val} -lt 16 ]]
}

# Clear APP_VERSION if it's an uninterpolated placeholder (use default from app.yaml)
if _needs_value "${APP_VERSION:-}"; then
    unset APP_VERSION
    log_info "[devtron/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Credential generation ---
if _needs_password "${PARAM_DEVTRON_DB_PASSWORD:-}"; then
    PARAM_DEVTRON_DB_PASSWORD="$(_generate_password)"
    export PARAM_DEVTRON_DB_PASSWORD
    log_info "[devtron/pre-install] Generated PostgreSQL password."
fi

if _needs_password "${PARAM_DEVTRON_ADMIN_PASSWORD:-}"; then
    PARAM_DEVTRON_ADMIN_PASSWORD="$(_generate_password)"
    export PARAM_DEVTRON_ADMIN_PASSWORD
    log_info "[devtron/pre-install] Generated admin password."
fi

# --- Auth fields for ArgoCD session client (Devtron Hyperion uses this) ---
# htpasswd (from apache2-utils) generates bcrypt hashes
if ! command -v htpasswd &>/dev/null; then
    log_info "[devtron/pre-install] Installing apache2-utils for bcrypt hash generation..."
    apt-get update -qq && apt-get install -y -qq apache2-utils
fi

# Generate bcrypt hash of admin password ($2y$ format, accepted by Go's bcrypt)
PARAM_DEVTRON_ADMIN_PASSWORD_HASH="$(htpasswd -bnBC 10 "" "$PARAM_DEVTRON_ADMIN_PASSWORD" | tr -d ':\n')"
export PARAM_DEVTRON_ADMIN_PASSWORD_HASH

# Password modification time (RFC3339)
PARAM_DEVTRON_ADMIN_PASSWORD_MTIME="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
export PARAM_DEVTRON_ADMIN_PASSWORD_MTIME

# Server signing key for JWT tokens (HMAC-SHA256)
PARAM_DEVTRON_SERVER_SECRET="$(openssl rand -hex 32)"
export PARAM_DEVTRON_SERVER_SECRET

log_info "[devtron/pre-install] Generated auth fields (bcrypt hash, server secret)."

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

# --- Create devtroncd namespace + secrets (Hyperion binary hardcodes this namespace) ---
log_info "[devtron/pre-install] Creating devtroncd namespace and secrets for Hyperion..."
kubectl create namespace devtroncd --dry-run=client -o yaml | kubectl apply -f -

# devtron-secret: DB credentials + ArgoCD session auth fields
kubectl apply -f - <<SECEOF
apiVersion: v1
kind: Secret
metadata:
  name: devtron-secret
  namespace: devtroncd
type: Opaque
stringData:
  PG_PASSWORD: "${PARAM_DEVTRON_DB_PASSWORD}"
  ADMIN_PASSWORD: "${PARAM_DEVTRON_ADMIN_PASSWORD}"
  POSTGRES_PASSWORD: "${PARAM_DEVTRON_DB_PASSWORD}"
  POSTGRES_USER: "postgres"
  POSTGRES_DB: "orchestrator"
  admin.password: "${PARAM_DEVTRON_ADMIN_PASSWORD_HASH}"
  admin.passwordMtime: "${PARAM_DEVTRON_ADMIN_PASSWORD_MTIME}"
  server.secretkey: "${PARAM_DEVTRON_SERVER_SECRET}"
SECEOF

# argocd-secret + argocd-cm: Required by authenticator library (GetArgocdConfig fails without them)
kubectl apply -f - <<ARGOEOF
apiVersion: v1
kind: Secret
metadata:
  name: argocd-secret
  namespace: devtroncd
type: Opaque
data: {}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: devtroncd
data:
  admin.enabled: "true"
ARGOEOF

log_info "[devtron/pre-install] devtron-secret, argocd-secret, argocd-cm created in devtroncd."

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

    # Orchestrator API needs its own HTTPRoute (/orchestrator/* → devtron-orchestrator:80)
    ns="${HELM_NAMESPACE_PREFIX}devtron"
    log_info "[devtron/pre-install] Applying HTTPRoute for orchestrator API..."
    kubectl apply -f - <<ORCHEOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: devtron-orchestrator
  namespace: ${ns}
spec:
  parentRefs:
    - name: app-gateway
      sectionName: websecure
  hostnames:
    - "${SSL_HOSTNAME}"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /orchestrator
      backendRefs:
        - name: devtron-orchestrator
          port: 80
ORCHEOF

    # Redirect / → /dashboard/ (Devtron dashboard expects /dashboard/ path prefix)
    log_info "[devtron/pre-install] Applying HTTPRoute for root → /dashboard/ redirect..."
    kubectl apply -f - <<REDIREOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: devtron-root-redirect
  namespace: ${ns}
spec:
  parentRefs:
    - name: app-gateway
      sectionName: websecure
  hostnames:
    - "${SSL_HOSTNAME}"
  rules:
    - matches:
        - path:
            type: Exact
            value: /
      filters:
        - type: RequestRedirect
          requestRedirect:
            path:
              type: ReplaceFullPath
              replaceFullPath: /dashboard/
            statusCode: 302
REDIREOF
else
    log_info "[devtron/pre-install] SSL disabled — access via NodePort only."
fi

log_info "[devtron/pre-install] Pre-install complete."
readonly _DEVTRON_PRE_INSTALL_DONE=1
export _DEVTRON_PRE_INSTALL_DONE
