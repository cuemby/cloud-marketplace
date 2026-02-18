#!/usr/bin/env bash
# post-install.sh — Superset post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[superset/post-install] Superset deployed successfully."
log_info "[superset/post-install] Dashboard: https://${PARAM_SUPERSET_HOSTNAME:-<unknown>}"
log_info "[superset/post-install] Note: TLS cert may take 60-120 seconds to provision."
