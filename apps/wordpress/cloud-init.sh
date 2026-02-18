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
export APP_VERSION="{{app-version}}"

# Credentials (Cuemby Cloud interpolates {{...}}; auto-generated otherwise)
export PARAM_MARIADB_ROOT_PASSWORD="{{param-mariadb-root-password}}"
export PARAM_MARIADB_PASSWORD="{{param-mariadb-password}}"
export PARAM_WORDPRESS_ADMIN_PASSWORD="{{param-wordpress-admin-password}}"

# Optional parameters (Cuemby Cloud interpolates; defaults applied in pre-install hook)
export PARAM_WORDPRESS_ADMIN_USER="{{param-wordpress-admin-user}}"
export PARAM_WORDPRESS_ADMIN_EMAIL="{{param-wordpress-admin-email}}"
export PARAM_WORDPRESS_SITE_TITLE="{{param-wordpress-site-title}}"
export PARAM_WORDPRESS_DATA_SIZE="{{param-wordpress-data-size}}"
export PARAM_MARIADB_DATA_SIZE="{{param-mariadb-data-size}}"

# -- Deploy --
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
