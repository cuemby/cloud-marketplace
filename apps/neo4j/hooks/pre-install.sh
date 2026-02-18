#!/usr/bin/env bash
# pre-install.sh — Neo4j pre-install hook.
# Sets up SSL hostname and Gateway API resources for the browser interface.
#
# This script is SOURCED (not subshelled) so exported vars propagate.

# Guard: only run setup once
[[ -n "${_NEO4J_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/ssl-hooks.sh
source "${BOOTSTRAP_DIR}/lib/ssl-hooks.sh"

# One call: detect hostname -> create Gateway -> create HTTPRoutes
# Neo4j browser HTTP port is 7474
ssl_full_setup "neo4j" "PARAM_NEO4J_HOSTNAME" "neo4j" 7474 "neo4j-tls"

export _NEO4J_PRE_INSTALL_DONE=1
