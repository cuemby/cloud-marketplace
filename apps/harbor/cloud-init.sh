#!/bin/bash
# Bash user-data script for deploying Harbor via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Harbor is a cloud-native container registry with vulnerability scanning,
# content signing, and role-based access control.
#
# All passwords are auto-generated if not provided.
#
# VM requirements: 4 CPU, 8 GB RAM, 100 GB disk, Ubuntu 22.04+ recommended.
# Firewall: allow inbound TCP on port 30443 (HTTPS).

set -euo pipefail

# -- Install prerequisites --
apt-get update -y
apt-get install -y curl git jq

# -- Application configuration --
export APP_NAME="harbor"
export APP_VERSION="{{app-version}}"

# Credentials (Cuemby Cloud interpolates {{...}}; auto-generated otherwise)
export PARAM_HARBOR_ADMIN_PASSWORD="{{param-harbor-admin-password}}"
export PARAM_HARBOR_DB_PASSWORD="{{param-harbor-db-password}}"
export PARAM_HARBOR_SECRET_KEY="{{param-harbor-secret-key}}"
export PARAM_HARBOR_VALKEY_PASSWORD="{{param-harbor-valkey-password}}"

# Optional parameters (defaults applied in pre-install hook)
export PARAM_HARBOR_REGISTRY_DATA_SIZE="{{param-harbor-registry-data-size}}"
export PARAM_HARBOR_DB_DATA_SIZE="{{param-harbor-db-data-size}}"
export PARAM_HARBOR_SSL_ENABLED="{{param-harbor-ssl-enabled}}"
export PARAM_HARBOR_HOSTNAME="{{param-harbor-hostname}}"

# -- Deploy --
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
