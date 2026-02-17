#!/bin/bash
# Bash user-data script for deploying WordPress via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
# Replace CHANGE_ME values with your own, then pass this script as user-data when creating a VM.
#
# VM requirements: 2 CPU, 4 GB RAM, 20 GB disk, Ubuntu 22.04 LTS recommended.
# Firewall: allow inbound TCP on ports 30080 (HTTP) and 30443 (HTTPS).

set -euo pipefail

# ── Install prerequisites ────────────────────────────────────────────────────
apt-get update -y
apt-get install -y curl git jq

# ── Application configuration ────────────────────────────────────────────────
export APP_NAME="wordpress"
export APP_VERSION="28.1.9"

# Required parameters
export PARAM_WORDPRESS_USERNAME="admin"
export PARAM_WORDPRESS_PASSWORD="CHANGE_ME"
export PARAM_WORDPRESS_EMAIL="admin@example.com"
export PARAM_MARIADB_ROOT_PASSWORD="CHANGE_ME"
export PARAM_MARIADB_PASSWORD="CHANGE_ME"

# Optional parameters (defaults shown)
export PARAM_WORDPRESS_BLOG_NAME="My Cuemby Blog"
export PARAM_WORDPRESS_FIRST_NAME="Admin"
export PARAM_WORDPRESS_LAST_NAME="User"

# ── Deploy ───────────────────────────────────────────────────────────────────
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
