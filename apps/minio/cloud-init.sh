#!/bin/bash
# Bash user-data script for deploying MinIO via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Parameters can be set as environment variables before running this script,
# or they will use the default values shown below.
#
# VM requirements: 2 CPU, 4 GB RAM, 50 GB disk, Ubuntu 22.04 LTS recommended.
# Firewall: allow inbound TCP on ports 80 (HTTP), 443 (HTTPS), and 30900 (S3 API).

set -euo pipefail

# ── Install prerequisites ────────────────────────────────────────────────────
apt-get update -y
apt-get install -y curl git jq

# ── Application configuration ────────────────────────────────────────────────
export APP_NAME="minio"
export APP_VERSION="${APP_VERSION:-17.0.21}"

# Required parameters
export PARAM_MINIO_ROOT_USER="${PARAM_MINIO_ROOT_USER:-admin}"
export PARAM_MINIO_ROOT_PASSWORD="${PARAM_MINIO_ROOT_PASSWORD:?PARAM_MINIO_ROOT_PASSWORD is required}"

# SSL parameters (optional — hostname auto-detected via sslip.io if not set)
export PARAM_MINIO_HOSTNAME="${PARAM_MINIO_HOSTNAME:-}"
export ACME_EMAIL="${ACME_EMAIL:?ACME_EMAIL is required for SSL}"
export ACME_USE_STAGING="${ACME_USE_STAGING:-false}"

# ── Deploy ───────────────────────────────────────────────────────────────────
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
