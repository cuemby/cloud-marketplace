#!/usr/bin/env bash
# post-install.sh — PostgreSQL post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[postgresql/post-install] PostgreSQL deployed successfully."
log_info "[postgresql/post-install] Connect: psql -h <VM_IP> -p 30432 -U postgres"
