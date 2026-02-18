#!/usr/bin/env bash
# post-install.sh — Jenkins post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[jenkins/post-install] Jenkins deployed successfully."
log_info "[jenkins/post-install] Access: https://${PARAM_JENKINS_HOSTNAME:-<unknown>}"
log_info "[jenkins/post-install] Note: Jenkins may take 2-3 minutes to fully start (JVM)."
log_info "[jenkins/post-install] Note: TLS cert may take 60-120 seconds to provision."
