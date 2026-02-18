#!/usr/bin/env bash
# post-install.sh — SonarQube post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[sonarqube/post-install] SonarQube deployed successfully."
log_info "[sonarqube/post-install] Access: https://${PARAM_SONARQUBE_HOSTNAME:-<unknown>}"
log_info "[sonarqube/post-install] Note: SonarQube (JVM) may take 3-5 minutes to fully start."
log_info "[sonarqube/post-install] Note: TLS cert may take 60-120 seconds to provision."
