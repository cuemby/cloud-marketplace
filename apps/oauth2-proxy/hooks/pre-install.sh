#!/usr/bin/env bash
# pre-install.sh — OAuth2 Proxy pre-install hook.
# Detects the VM's public IP, computes a sslip.io hostname, exports
# PARAM_OAUTH2_PROXY_HOSTNAME, and applies Gateway + HTTPRoute resources.
#
# This script is SOURCED (not subshelled) so exported vars propagate
# to deploy-app.sh's build_set_args and post-install/healthcheck hooks.

# Guard: only run setup once (idempotent when sourced multiple times)
[[ -n "${_OAUTH2_PROXY_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/ssl-hooks.sh
source "${BOOTSTRAP_DIR}/lib/ssl-hooks.sh"

# One call: detect hostname -> create Gateway -> create HTTPRoutes
ssl_full_setup "oauth2-proxy" "PARAM_OAUTH2_PROXY_HOSTNAME" "oauth2-proxy" 4180 "oauth2-proxy-tls"

export _OAUTH2_PROXY_PRE_INSTALL_DONE=1
