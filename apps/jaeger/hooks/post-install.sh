#!/usr/bin/env bash
# post-install.sh — Jaeger post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[jaeger/post-install] Jaeger deployed successfully."
log_info "[jaeger/post-install] UI: https://${PARAM_JAEGER_HOSTNAME:-<unknown>}"
log_info "[jaeger/post-install] Collector (gRPC): <VM_IP>:31468"
log_info "[jaeger/post-install] Note: TLS cert may take 60-120 seconds to provision."
