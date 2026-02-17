#!/usr/bin/env bash
# pre-install.sh — WordPress pre-install hook.
# Runs before helm install. Use for any pre-deployment setup.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[wordpress/pre-install] No pre-install steps required."
