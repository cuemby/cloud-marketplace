#!/usr/bin/env bash
# pre-install.sh — phpMyAdmin pre-install hook.
# Sets up SSL hostname and Gateway API resources.
#
# This script is SOURCED (not subshelled) so exported vars propagate.

# Guard: only run setup once
[[ -n "${_PMA_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/ssl-hooks.sh
source "${BOOTSTRAP_DIR}/lib/ssl-hooks.sh"

# One call: detect hostname -> create Gateway -> create HTTPRoutes
ssl_full_setup "phpmyadmin" "PARAM_PHPMYADMIN_HOSTNAME" "phpmyadmin" 80 "phpmyadmin-tls"

export _PMA_PRE_INSTALL_DONE=1
