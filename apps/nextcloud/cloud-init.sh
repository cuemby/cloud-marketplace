#!/bin/bash
# Bash user-data script for deploying Nextcloud via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Passwords are auto-generated if not provided.
#
# VM requirements: 2 CPU, 4 GB RAM, 50 GB disk, Ubuntu 22.04+ recommended.
# Firewall: allow inbound TCP on port 30080 (HTTP).

set -euo pipefail

# -- Install prerequisites --
apt-get update -y
apt-get install -y curl git jq

# -- Application configuration --
export APP_NAME="nextcloud"
export APP_VERSION="{{app-version}}"

# Credentials (Cuemby Cloud interpolates {{...}}; auto-generated otherwise)
export PARAM_NEXTCLOUD_ADMIN_PASSWORD="{{param-nextcloud-admin-password}}"
export PARAM_NEXTCLOUD_DB_PASSWORD="{{param-nextcloud-db-password}}"
export PARAM_NEXTCLOUD_DB_ROOT_PASSWORD="{{param-nextcloud-db-root-password}}"
export PARAM_NEXTCLOUD_VALKEY_PASSWORD="{{param-nextcloud-valkey-password}}"

# Optional parameters (Cuemby Cloud interpolates; defaults applied in pre-install hook)
export PARAM_NEXTCLOUD_ADMIN_USER="{{param-nextcloud-admin-user}}"
export PARAM_NEXTCLOUD_DB_DATA_SIZE="{{param-nextcloud-db-data-size}}"
export PARAM_NEXTCLOUD_DATA_SIZE="{{param-nextcloud-data-size}}"

# -- Deploy --
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
