#!/usr/bin/env bash
# post-install.sh — Neo4j post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[neo4j/post-install] Neo4j deployed successfully."
log_info "[neo4j/post-install] Browser: https://${PARAM_NEO4J_HOSTNAME:-<unknown>}"
log_info "[neo4j/post-install] Bolt:    bolt://<VM_IP>:30687"
log_info "[neo4j/post-install] Note: TLS cert may take 60-120 seconds to provision."
