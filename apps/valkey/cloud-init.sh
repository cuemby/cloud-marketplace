#!/bin/bash
# Bash user-data script for deploying Valkey via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Password is auto-generated if not provided.
#
# VM requirements: 2 CPU, 4 GB RAM, 20 GB disk, Ubuntu 22.04+ recommended.
# Firewall: allow inbound TCP on port 30379 (Valkey protocol).

set -euo pipefail

# -- Install prerequisites --
apt-get update -y
apt-get install -y curl git jq

# -- Application configuration --
export APP_NAME="valkey"
export APP_VERSION="{{app-version}}"

# Credentials (Cuemby Cloud interpolates {{...}}; auto-generated otherwise)
export PARAM_VALKEY_PASSWORD="{{param-valkey-password}}"

# Optional parameters (Cuemby Cloud interpolates; defaults applied in pre-install hook)
export PARAM_VALKEY_DATA_SIZE="{{param-valkey-data-size}}"
export PARAM_VALKEY_MAXMEMORY="{{param-valkey-maxmemory}}"
export PARAM_VALKEY_MAXMEMORY_POLICY="{{param-valkey-maxmemory-policy}}"

# -- Deploy --
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
