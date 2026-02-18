#!/usr/bin/env bash
# post-install.sh — Mastodon post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[mastodon/post-install] Mastodon deployed successfully."
log_info "[mastodon/post-install] Site: https://${PARAM_MASTODON_HOSTNAME:-<unknown>}"
log_info "[mastodon/post-install] Note: TLS cert may take 60-120 seconds to provision."
log_info "[mastodon/post-install] Note: Mastodon initial setup may take several minutes."
log_info "[mastodon/post-install] Note: Elasticsearch indexing may take additional time."
