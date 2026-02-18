#!/bin/bash
# Bash user-data script for deploying WordPress via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Passwords are auto-generated if not provided.
#
# VM requirements: 2 CPU, 4 GB RAM, 30 GB disk, Ubuntu 22.04+ recommended.
# Firewall: allow inbound TCP on port 30080 (HTTP).

set -euo pipefail

# -- Install prerequisites --
apt-get update -y
apt-get install -y curl git jq

# -- Application configuration --
export APP_NAME="wordpress"
export APP_VERSION="${APP_VERSION:-6.9.1}"

# Credentials (auto-generated if not set)
export PARAM_MARIADB_ROOT_PASSWORD="${PARAM_MARIADB_ROOT_PASSWORD:-}"
export PARAM_MARIADB_PASSWORD="${PARAM_MARIADB_PASSWORD:-}"
export PARAM_WORDPRESS_ADMIN_PASSWORD="${PARAM_WORDPRESS_ADMIN_PASSWORD:-}"

# Optional parameters
export PARAM_WORDPRESS_ADMIN_USER="${PARAM_WORDPRESS_ADMIN_USER:-admin}"
export PARAM_WORDPRESS_ADMIN_EMAIL="${PARAM_WORDPRESS_ADMIN_EMAIL:-admin@example.com}"
export PARAM_WORDPRESS_SITE_TITLE="${PARAM_WORDPRESS_SITE_TITLE:-My WordPress Site}"
export PARAM_WORDPRESS_DATA_SIZE="${PARAM_WORDPRESS_DATA_SIZE:-10Gi}"
export PARAM_MARIADB_DATA_SIZE="${PARAM_MARIADB_DATA_SIZE:-5Gi}"

# -- Deploy --
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
