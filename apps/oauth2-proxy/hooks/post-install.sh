#!/usr/bin/env bash
# post-install.sh — OAuth2 Proxy post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[oauth2-proxy/post-install] OAuth2 Proxy deployed successfully."
log_info "[oauth2-proxy/post-install] Proxy: https://${PARAM_OAUTH2_PROXY_HOSTNAME:-<unknown>}"
log_info "[oauth2-proxy/post-install] Callback URL: https://${PARAM_OAUTH2_PROXY_HOSTNAME:-<unknown>}/oauth2/callback"
log_info "[oauth2-proxy/post-install] Note: Configure your OAuth provider with the callback URL above."
log_info "[oauth2-proxy/post-install] Note: TLS cert may take 60-120 seconds to provision."
