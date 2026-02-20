#!/bin/bash
set -euo pipefail

apt-get update -y
apt-get install -y curl git jq

export APP_NAME="portainer"
export APP_VERSION="{{app-version}}"
export PARAM_PORTAINER_DATA_SIZE="{{param-portainer-data-size}}"
export PARAM_PORTAINER_SSL_ENABLED="{{param-portainer-ssl-enabled}}"
export PARAM_PORTAINER_HOSTNAME="{{param-portainer-hostname}}"

git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
