#!/usr/bin/env bash
# pre-install.sh — MLflow pre-install hook.
# Sets up SSL hostname and Gateway API resources.
#
# This script is SOURCED (not subshelled) so exported vars propagate
# to deploy-app.sh's build_set_args and post-install/healthcheck hooks.

# Guard: only run setup once (idempotent when sourced multiple times)
[[ -n "${_MLFLOW_PRE_INSTALL_DONE:-}" ]] && return 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/ssl-hooks.sh
source "${BOOTSTRAP_DIR}/lib/ssl-hooks.sh"

# One call: detect hostname -> create Gateway -> create HTTPRoutes
ssl_full_setup "mlflow" "PARAM_MLFLOW_HOSTNAME" "mlflow-tracking" 5000 "mlflow-tls"

export _MLFLOW_PRE_INSTALL_DONE=1
