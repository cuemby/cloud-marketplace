#!/usr/bin/env bash
# pre-install.sh — Jaeger pre-install hook.
# Sets up SSL hostname and Gateway API resources for the Query UI.
#
# This script is SOURCED (not subshelled) so exported vars propagate.

# Guard: only run setup once
[[ -n "${_JAEGER_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/ssl-hooks.sh
source "${BOOTSTRAP_DIR}/lib/ssl-hooks.sh"

# One call: detect hostname -> create Gateway -> create HTTPRoutes
# Routes to Jaeger Query UI on port 16686
ssl_full_setup "jaeger" "PARAM_JAEGER_HOSTNAME" "jaeger-query" 16686 "jaeger-tls"

export _JAEGER_PRE_INSTALL_DONE=1
