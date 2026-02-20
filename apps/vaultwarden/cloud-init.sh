#!/bin/bash
set -euo pipefail

apt-get update -y
apt-get install -y curl git jq

export APP_NAME="vaultwarden"
export APP_VERSION="{{app-version}}"
export PARAM_VAULTWARDEN_ADMIN_TOKEN="{{param-vaultwarden-admin-token}}"
export PARAM_VAULTWARDEN_DATA_SIZE="{{param-vaultwarden-data-size}}"
export PARAM_VAULTWARDEN_SSL_ENABLED="{{param-vaultwarden-ssl-enabled}}"
export PARAM_VAULTWARDEN_HOSTNAME="{{param-vaultwarden-hostname}}"

git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
