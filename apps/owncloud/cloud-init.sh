#!/bin/bash
# Bash user-data script for deploying ownCloud via Cuemby Cloud Marketplace.
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
export APP_NAME="owncloud"
export APP_VERSION="{{app-version}}"

# Credentials (Cuemby Cloud interpolates {{...}}; auto-generated otherwise)
export PARAM_OWNCLOUD_ADMIN_PASSWORD="{{param-owncloud-admin-password}}"
export PARAM_OWNCLOUD_DB_PASSWORD="{{param-owncloud-db-password}}"
export PARAM_OWNCLOUD_DB_ROOT_PASSWORD="{{param-owncloud-db-root-password}}"
export PARAM_OWNCLOUD_VALKEY_PASSWORD="{{param-owncloud-valkey-password}}"

# Optional parameters (Cuemby Cloud interpolates; defaults applied in pre-install hook)
export PARAM_OWNCLOUD_ADMIN_USERNAME="{{param-owncloud-admin-username}}"
export PARAM_OWNCLOUD_DB_DATA_SIZE="{{param-owncloud-db-data-size}}"
export PARAM_OWNCLOUD_DATA_SIZE="{{param-owncloud-data-size}}"

# -- Deploy --
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
