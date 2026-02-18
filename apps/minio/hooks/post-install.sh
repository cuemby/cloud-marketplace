#!/usr/bin/env bash
# post-install.sh — MinIO post-install hook.
# Runs after helm install succeeds. Use for post-deployment configuration.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"

log_info "[minio/post-install] MinIO deployed successfully."
log_info "[minio/post-install] Console: https://${PARAM_MINIO_HOSTNAME:-<unknown>}"
log_info "[minio/post-install] S3 API:  http://<VM_IP>:30900"
log_info "[minio/post-install] Note: TLS cert may take 60-120 seconds to provision."
