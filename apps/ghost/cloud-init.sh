#!/bin/bash
# Bash user-data script for deploying Ghost via Cuemby Cloud Marketplace.
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
export APP_NAME="ghost"
export APP_VERSION="{{app-version}}"

# Credentials (Cuemby Cloud interpolates {{...}}; auto-generated otherwise)
export PARAM_GHOST_DB_PASSWORD="{{param-ghost-db-password}}"
export PARAM_GHOST_DB_ROOT_PASSWORD="{{param-ghost-db-root-password}}"

# Optional parameters (Cuemby Cloud interpolates; defaults applied in pre-install hook)
export PARAM_GHOST_DB_DATA_SIZE="{{param-ghost-db-data-size}}"
export PARAM_GHOST_DATA_SIZE="{{param-ghost-data-size}}"
export PARAM_GHOST_SSL_ENABLED="{{param-ghost-ssl-enabled}}"
export PARAM_GHOST_HOSTNAME="{{param-ghost-hostname}}"

# -- Deploy --
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
