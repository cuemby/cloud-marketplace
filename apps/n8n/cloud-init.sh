#!/bin/bash
# Bash user-data script for deploying n8n via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Passwords and encryption key are auto-generated if not provided.
#
# VM requirements: 2 CPU, 4 GB RAM, 30 GB disk, Ubuntu 22.04+ recommended.
# Firewall: allow inbound TCP on port 30080 (n8n web UI).

set -euo pipefail

# -- Install prerequisites --
apt-get update -y
apt-get install -y curl git jq

# -- Application configuration --
export APP_NAME="n8n"
export APP_VERSION="{{app-version}}"

# Credentials (Cuemby Cloud interpolates {{...}}; auto-generated otherwise)
export PARAM_N8N_DB_PASSWORD="{{param-n8n-db-password}}"
export PARAM_N8N_ENCRYPTION_KEY="{{param-n8n-encryption-key}}"

# Optional parameters (Cuemby Cloud interpolates; defaults applied in pre-install hook)
export PARAM_N8N_DB_DATA_SIZE="{{param-n8n-db-data-size}}"
export PARAM_N8N_DATA_SIZE="{{param-n8n-data-size}}"
export PARAM_N8N_SSL_ENABLED="{{param-n8n-ssl-enabled}}"
export PARAM_N8N_HOSTNAME="{{param-n8n-hostname}}"

# -- Deploy --
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
