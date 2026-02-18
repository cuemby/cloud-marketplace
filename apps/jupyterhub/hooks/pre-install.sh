#!/usr/bin/env bash
# pre-install.sh — JupyterHub pre-install hook.
# Sets up SSL hostname and Gateway API resources.
#
# This script is SOURCED (not subshelled) so exported vars propagate.

# Guard: only run setup once
[[ -n "${_JUPYTERHUB_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/ssl-hooks.sh
source "${BOOTSTRAP_DIR}/lib/ssl-hooks.sh"

# One call: detect hostname -> create Gateway -> create HTTPRoutes
# proxy-public service handles routing to hub and singleuser pods
ssl_full_setup "jupyterhub" "PARAM_JUPYTERHUB_HOSTNAME" "jupyterhub-proxy-public" 80 "jupyterhub-tls"

export _JUPYTERHUB_PRE_INSTALL_DONE=1
