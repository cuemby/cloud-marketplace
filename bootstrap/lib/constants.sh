#!/usr/bin/env bash
# constants.sh — Shared constants for the bootstrap system.
# Source this file; do not execute directly.
# shellcheck disable=SC2034  # Variables are used by scripts that source this file.

# Source guard: skip if already loaded (readonly vars can't be re-declared)
[[ -n "${_CONSTANTS_LOADED:-}" ]] && return 0
readonly _CONSTANTS_LOADED=1

# Paths
readonly MARKETPLACE_DIR="/opt/cuemby/marketplace"
readonly APPS_DIR="${MARKETPLACE_DIR}/apps"
readonly LOG_DIR="/var/log/cuemby"
readonly LOG_FILE="${LOG_DIR}/bootstrap.log"
readonly STATE_DIR="/var/lib/cuemby"
readonly STATE_FILE="${STATE_DIR}/marketplace-state.json"
readonly KUBECONFIG_PATH="/etc/rancher/k3s/k3s.yaml"

# Timeouts (seconds)
readonly TIMEOUT_K3S=300
readonly TIMEOUT_HELM_DEPLOY=600
readonly TIMEOUT_HEALTH=300
readonly TIMEOUT_NETWORK=120
readonly TIMEOUT_DNS=60

# Retry defaults
readonly RETRY_MAX_ATTEMPTS=30
readonly RETRY_INTERVAL=10
readonly RETRY_BACKOFF_MAX=60

# Default versions
readonly DEFAULT_K3S_CHANNEL="stable"
readonly DEFAULT_HELM_VERSION="v3.17.0"

# K3s flags (Traefik enabled — serves as Gateway API controller)
readonly K3S_INSTALL_FLAGS="--write-kubeconfig-mode=644"

# Helm defaults
readonly HELM_NAMESPACE_PREFIX="app-"
readonly HELM_ATOMIC="--atomic"
readonly HELM_WAIT="--wait"

# NodePort defaults
readonly DEFAULT_HTTP_NODEPORT=30080
readonly DEFAULT_HTTPS_NODEPORT=30443

# cert-manager
readonly CERT_MANAGER_VERSION="${CERT_MANAGER_VERSION:-v1.17.0}"
readonly CERT_MANAGER_NAMESPACE="cert-manager"
readonly TIMEOUT_CERT_MANAGER=300
readonly ACME_SERVER_PROD="https://acme-v02.api.letsencrypt.org/directory"
readonly ACME_SERVER_STAGING="https://acme-staging-v02.api.letsencrypt.org/directory"
readonly DEFAULT_ACME_SERVER="${ACME_SERVER_PROD}"

# State machine phases
readonly STATE_VALIDATING="validating"
readonly STATE_PREPARING="preparing"
readonly STATE_INSTALLING_K3S="installing_k3s"
readonly STATE_INSTALLING_SSL="installing_ssl"
readonly STATE_INSTALLING_HELM="installing_helm"
readonly STATE_DEPLOYING="deploying"
readonly STATE_HEALTHCHECK="healthcheck"
readonly STATE_READY="ready"
readonly STATE_ERROR="error"
