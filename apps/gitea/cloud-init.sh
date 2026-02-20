#!/bin/bash
# Bash user-data script for deploying Gitea via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Admin account is created via Gitea's first-visit install wizard.
#
# VM requirements: 2 CPU, 4 GB RAM, 30 GB disk, Ubuntu 22.04+ recommended.
# Firewall: allow inbound TCP on ports 30300 (HTTP) and 30022 (SSH).

set -euo pipefail

# -- Install prerequisites --
apt-get update -y
apt-get install -y curl git jq

# -- Application configuration --
export APP_NAME="gitea"
export APP_VERSION="{{app-version}}"

# Optional parameters (Cuemby Cloud interpolates; defaults applied in pre-install hook)
export PARAM_GITEA_DATA_SIZE="{{param-gitea-data-size}}"
export PARAM_GITEA_SSL_ENABLED="{{param-gitea-ssl-enabled}}"
export PARAM_GITEA_HOSTNAME="{{param-gitea-hostname}}"

# -- Deploy --
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
