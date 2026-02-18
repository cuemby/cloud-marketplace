#!/bin/bash
# Bash user-data script for deploying Coolify via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Credentials are auto-generated if not provided.
#
# VM requirements: 2 CPU, 4 GB RAM, 50 GB disk, Ubuntu 22.04+ recommended.
# Firewall: allow inbound TCP on ports 30800 (UI), 80 (HTTP), 443 (HTTPS).

set -euo pipefail

# -- Install prerequisites --
apt-get update -y
apt-get install -y curl git jq

# -- Application configuration --
export APP_NAME="coolify"
export APP_VERSION="{{app-version}}"

# Credentials (Cuemby Cloud interpolates {{...}}; auto-generated otherwise)
export PARAM_COOLIFY_DB_PASSWORD="{{param-coolify-db-password}}"
export PARAM_COOLIFY_REDIS_PASSWORD="{{param-coolify-redis-password}}"
export PARAM_COOLIFY_APP_KEY="{{param-coolify-app-key}}"
export PARAM_COOLIFY_PUSHER_APP_KEY="{{param-coolify-pusher-app-key}}"
export PARAM_COOLIFY_PUSHER_APP_SECRET="{{param-coolify-pusher-app-secret}}"

# Optional parameters (Cuemby Cloud interpolates; defaults applied in pre-install hook)
export PARAM_COOLIFY_PUSHER_APP_ID="{{param-coolify-pusher-app-id}}"
export PARAM_COOLIFY_DB_DATA_SIZE="{{param-coolify-db-data-size}}"
export PARAM_COOLIFY_DATA_SIZE="{{param-coolify-data-size}}"

# -- Deploy --
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
