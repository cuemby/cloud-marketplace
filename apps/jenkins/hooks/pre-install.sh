#!/usr/bin/env bash
# pre-install.sh — Jenkins pre-install hook.
# Sets resource defaults and exports all PARAM_* vars.
# This script is SOURCED (not subshelled) so exports propagate to deploy-manifest.sh.
set -euo pipefail

[[ -n "${_JENKINS_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/ssl-hooks.sh
source "${BOOTSTRAP_DIR}/lib/ssl-hooks.sh"

log_info "[jenkins/pre-install] Setting defaults and generating credentials..."

# --- Password generation (alphanumeric only) ---
_generate_password() {
    openssl rand -base64 48 | tr -d '/+=' | head -c 32
}

# Check if a value is empty or an uninterpolated {{placeholder}}
_needs_value() {
    local val="${1:-}"
    [[ -z "$val" || "$val" == \{\{*\}\} ]]
}

# Clear APP_VERSION if it's an uninterpolated placeholder (use default from app.yaml)
if _needs_value "${APP_VERSION:-}"; then
    unset APP_VERSION
    log_info "[jenkins/pre-install] APP_VERSION not set — will use default from app.yaml."
fi

# --- Credential generation ---
if _needs_value "${PARAM_JENKINS_ADMIN_PASSWORD:-}"; then
    PARAM_JENKINS_ADMIN_PASSWORD="$(_generate_password)"
    export PARAM_JENKINS_ADMIN_PASSWORD
    log_info "[jenkins/pre-install] Generated admin password."
fi

# --- Non-secret parameter defaults ---
_needs_value "${PARAM_JENKINS_DATA_SIZE:-}" && PARAM_JENKINS_DATA_SIZE="20Gi"
_needs_value "${PARAM_JENKINS_JAVA_OPTS:-}" && PARAM_JENKINS_JAVA_OPTS="-Xms512m -Xmx1g"
# Skip setup wizard — admin user created by init groovy script
PARAM_JENKINS_JAVA_OPTS="${PARAM_JENKINS_JAVA_OPTS} -Djenkins.install.runSetupWizard=false"
export PARAM_JENKINS_DATA_SIZE
export PARAM_JENKINS_JAVA_OPTS

# --- NodePorts ---
_needs_value "${PARAM_JENKINS_HTTP_NODEPORT:-}" && PARAM_JENKINS_HTTP_NODEPORT="30080"
_needs_value "${PARAM_JENKINS_AGENT_NODEPORT:-}" && PARAM_JENKINS_AGENT_NODEPORT="30500"
export PARAM_JENKINS_HTTP_NODEPORT
export PARAM_JENKINS_AGENT_NODEPORT

# --- Resource limits (defaults target a 2-CPU / 4GB VM) ---
export PARAM_JENKINS_CPU_REQUEST="${PARAM_JENKINS_CPU_REQUEST:-500m}"
export PARAM_JENKINS_CPU_LIMIT="${PARAM_JENKINS_CPU_LIMIT:-2000m}"
export PARAM_JENKINS_MEMORY_REQUEST="${PARAM_JENKINS_MEMORY_REQUEST:-512Mi}"
export PARAM_JENKINS_MEMORY_LIMIT="${PARAM_JENKINS_MEMORY_LIMIT:-2Gi}"

# --- SSL / HTTPS ---
_needs_value "${PARAM_JENKINS_SSL_ENABLED:-}" && PARAM_JENKINS_SSL_ENABLED="true"
export PARAM_JENKINS_SSL_ENABLED

if [[ "${PARAM_JENKINS_SSL_ENABLED}" == "true" ]]; then
    if ! _needs_value "${PARAM_JENKINS_HOSTNAME:-}"; then
        PARAM_HOSTNAME="${PARAM_JENKINS_HOSTNAME}"
        export PARAM_HOSTNAME
    fi
    ssl_full_setup "jenkins" "PARAM_HOSTNAME" "jenkins-web" 80
    PARAM_JENKINS_HOSTNAME="${SSL_HOSTNAME}"
    export PARAM_JENKINS_HOSTNAME
    PARAM_JENKINS_URL="https://${PARAM_JENKINS_HOSTNAME}/"
    export PARAM_JENKINS_URL
    log_info "[jenkins/pre-install] SSL enabled — HTTPS hostname: ${SSL_HOSTNAME}"
else
    local_ip="$(ssl_detect_best_ip)"
    PARAM_JENKINS_HOSTNAME="${local_ip}"
    PARAM_JENKINS_URL="http://$(ssl_format_url_host "$local_ip"):${PARAM_JENKINS_HTTP_NODEPORT}/"
    export PARAM_JENKINS_HOSTNAME PARAM_JENKINS_URL
    log_info "[jenkins/pre-install] SSL disabled — access via NodePort only."
fi

log_info "[jenkins/pre-install] Pre-install complete."
readonly _JENKINS_PRE_INSTALL_DONE=1
export _JENKINS_PRE_INSTALL_DONE
