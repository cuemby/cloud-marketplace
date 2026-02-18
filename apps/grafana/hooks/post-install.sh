#!/usr/bin/env bash
# post-install.sh — Grafana post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[grafana/post-install] Grafana deployed successfully."
log_info "[grafana/post-install] Dashboard: https://${PARAM_GRAFANA_HOSTNAME:-<unknown>}"
log_info "[grafana/post-install] Note: TLS cert may take 60-120 seconds to provision."
