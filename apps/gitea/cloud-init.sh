#!/bin/bash
# Bash user-data script for deploying Gitea via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Parameters can be set as environment variables before running this script,
# or they will use the default values shown below.
#
# VM requirements: 2 CPU, 4 GB RAM, 20 GB disk, Ubuntu 22.04 LTS recommended.
# Firewall: allow inbound TCP on ports 80 (HTTP), 443 (HTTPS), and 30022 (SSH).

set -euo pipefail

# ── Install prerequisites ────────────────────────────────────────────────────
apt-get update -y
apt-get install -y curl git jq

# ── Application configuration ────────────────────────────────────────────────
export APP_NAME="gitea"
export APP_VERSION="${APP_VERSION:-3.2.22}"

# Required parameters
export PARAM_GITEA_ADMIN_USER="${PARAM_GITEA_ADMIN_USER:-gitea_admin}"
export PARAM_GITEA_ADMIN_PASSWORD="${PARAM_GITEA_ADMIN_PASSWORD:?PARAM_GITEA_ADMIN_PASSWORD is required}"
export PARAM_GITEA_ADMIN_EMAIL="${PARAM_GITEA_ADMIN_EMAIL:?PARAM_GITEA_ADMIN_EMAIL is required}"
export PARAM_GITEA_POSTGRES_PASSWORD="${PARAM_GITEA_POSTGRES_PASSWORD:?PARAM_GITEA_POSTGRES_PASSWORD is required}"

# SSL parameters (optional — hostname auto-detected via sslip.io if not set)
export PARAM_GITEA_HOSTNAME="${PARAM_GITEA_HOSTNAME:-}"
export ACME_EMAIL="${ACME_EMAIL:-${PARAM_GITEA_ADMIN_EMAIL}}"
export ACME_USE_STAGING="${ACME_USE_STAGING:-false}"

# ── Deploy ───────────────────────────────────────────────────────────────────
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
