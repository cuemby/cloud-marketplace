#!/usr/bin/env bash
# post-install.sh — RabbitMQ post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[rabbitmq/post-install] RabbitMQ deployed successfully."
log_info "[rabbitmq/post-install] AMQP:       amqp://<user>:<password>@<VM_IP>:30672"
log_info "[rabbitmq/post-install] Management: http://<VM_IP>:31672"
