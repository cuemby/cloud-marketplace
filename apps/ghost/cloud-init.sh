#!/bin/bash
# Bash user-data script for deploying Ghost via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Parameters can be set as environment variables before running this script,
# or they will use the default values shown below.
#
# VM requirements: 2 CPU, 4 GB RAM, 20 GB disk, Ubuntu 22.04 LTS recommended.
# Firewall: allow inbound TCP on ports 80 (HTTP) and 443 (HTTPS).

set -euo pipefail

# ── Install prerequisites ────────────────────────────────────────────────────
apt-get update -y
apt-get install -y curl git jq

# ── Application configuration ────────────────────────────────────────────────
export APP_NAME="ghost"
export APP_VERSION="${APP_VERSION:-25.0.4}"

# Required parameters
export PARAM_GHOST_EMAIL="${PARAM_GHOST_EMAIL:?PARAM_GHOST_EMAIL is required}"
export PARAM_GHOST_PASSWORD="${PARAM_GHOST_PASSWORD:?PARAM_GHOST_PASSWORD is required}"
export PARAM_MYSQL_ROOT_PASSWORD="${PARAM_MYSQL_ROOT_PASSWORD:?PARAM_MYSQL_ROOT_PASSWORD is required}"
export PARAM_MYSQL_PASSWORD="${PARAM_MYSQL_PASSWORD:?PARAM_MYSQL_PASSWORD is required}"

# Optional parameters
export PARAM_GHOST_USERNAME="${PARAM_GHOST_USERNAME:-user}"
export PARAM_GHOST_BLOG_TITLE="${PARAM_GHOST_BLOG_TITLE:-My Blog}"

# SSL parameters (optional — hostname auto-detected via sslip.io if not set)
export PARAM_GHOST_HOSTNAME="${PARAM_GHOST_HOSTNAME:-}"
export ACME_EMAIL="${ACME_EMAIL:-${PARAM_GHOST_EMAIL}}"
export ACME_USE_STAGING="${ACME_USE_STAGING:-false}"

# ── Deploy ───────────────────────────────────────────────────────────────────
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
