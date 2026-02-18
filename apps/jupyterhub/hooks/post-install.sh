#!/usr/bin/env bash
# post-install.sh — JupyterHub post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[jupyterhub/post-install] JupyterHub deployed successfully."
log_info "[jupyterhub/post-install] Dashboard: https://${PARAM_JUPYTERHUB_HOSTNAME:-<unknown>}"
log_info "[jupyterhub/post-install] Note: TLS cert may take 60-120 seconds to provision."
log_info "[jupyterhub/post-install] Single-user pods spawn on first login — allow extra time."
