#!/bin/bash
# Bash user-data script for deploying Kong Gateway via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Passwords are auto-generated if not provided.
#
# VM requirements: 2 CPU, 4 GB RAM, 20 GB disk, Ubuntu 22.04+ recommended.
# Firewall: allow inbound TCP on ports 30800 (Proxy) and 30801 (Admin API).

set -euo pipefail

# -- Install prerequisites --
apt-get update -y
apt-get install -y curl git jq

# -- Application configuration --
export APP_NAME="kong"
export APP_VERSION="{{app-version}}"

# Credentials (Cuemby Cloud interpolates {{...}}; auto-generated otherwise)
export PARAM_KONG_DB_PASSWORD="{{param-kong-db-password}}"

# Optional parameters (Cuemby Cloud interpolates; defaults applied in pre-install hook)
export PARAM_KONG_DB_DATA_SIZE="{{param-kong-db-data-size}}"
export PARAM_KONG_SSL_ENABLED="{{param-kong-ssl-enabled}}"
export PARAM_KONG_HOSTNAME="{{param-kong-hostname}}"

# -- Deploy --
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
