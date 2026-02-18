#!/usr/bin/env bash
# post-install.sh — Gitea post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[gitea/post-install] Gitea deployed successfully."
log_info "[gitea/post-install] Web:  https://${PARAM_GITEA_HOSTNAME:-<unknown>}"
log_info "[gitea/post-install] SSH:  git clone ssh://git@<VM_IP>:30022/<owner>/<repo>.git"
log_info "[gitea/post-install] Note: TLS cert may take 60-120 seconds to provision."
