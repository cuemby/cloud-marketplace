#!/bin/bash
set -euo pipefail

apt-get update -y
apt-get install -y curl git jq

export APP_NAME="openbao"
export APP_VERSION="{{app-version}}"
export PARAM_OPENBAO_DATA_SIZE="{{param-openbao-data-size}}"
export PARAM_OPENBAO_DEV_ROOT_TOKEN="{{param-openbao-dev-root-token}}"
export PARAM_OPENBAO_SSL_ENABLED="{{param-openbao-ssl-enabled}}"
export PARAM_OPENBAO_HOSTNAME="{{param-openbao-hostname}}"

git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
