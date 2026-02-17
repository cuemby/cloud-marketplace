#!/bin/bash
# Bash user-data script for deploying WordPress via Cuemby Cloud Marketplace.
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
export APP_NAME="wordpress"
export APP_VERSION="${APP_VERSION:-28.1.9}"

# Required parameters
export PARAM_WORDPRESS_USERNAME="${PARAM_WORDPRESS_USERNAME:-admin}"
export PARAM_WORDPRESS_PASSWORD="${PARAM_WORDPRESS_PASSWORD:?PARAM_WORDPRESS_PASSWORD is required}"
export PARAM_WORDPRESS_EMAIL="${PARAM_WORDPRESS_EMAIL:-admin@example.com}"
export PARAM_MARIADB_ROOT_PASSWORD="${PARAM_MARIADB_ROOT_PASSWORD:?PARAM_MARIADB_ROOT_PASSWORD is required}"
export PARAM_MARIADB_PASSWORD="${PARAM_MARIADB_PASSWORD:?PARAM_MARIADB_PASSWORD is required}"

# Optional parameters
export PARAM_WORDPRESS_BLOG_NAME="${PARAM_WORDPRESS_BLOG_NAME:-My Cuemby Blog}"
export PARAM_WORDPRESS_FIRST_NAME="${PARAM_WORDPRESS_FIRST_NAME:-Admin}"
export PARAM_WORDPRESS_LAST_NAME="${PARAM_WORDPRESS_LAST_NAME:-User}"

# SSL parameters (optional — hostname auto-detected via sslip.io if not set)
export PARAM_WORDPRESS_HOSTNAME="${PARAM_WORDPRESS_HOSTNAME:-}"
export ACME_EMAIL="${ACME_EMAIL:-${PARAM_WORDPRESS_EMAIL}}"
export ACME_USE_STAGING="${ACME_USE_STAGING:-false}"

# ── Deploy ───────────────────────────────────────────────────────────────────
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
