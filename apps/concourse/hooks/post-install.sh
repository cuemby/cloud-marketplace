#!/usr/bin/env bash
# post-install.sh — Concourse post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[concourse/post-install] Concourse deployed successfully."
log_info "[concourse/post-install] Site:  https://${PARAM_CONCOURSE_HOSTNAME:-<unknown>}"
log_info "[concourse/post-install] Note: TLS cert may take 60-120 seconds to provision."
