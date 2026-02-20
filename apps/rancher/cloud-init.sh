#!/bin/bash
set -euo pipefail

apt-get update -y
apt-get install -y curl git jq

export APP_NAME="rancher"
export APP_VERSION="{{app-version}}"
export PARAM_RANCHER_BOOTSTRAP_PASSWORD="{{param-rancher-bootstrap-password}}"
export PARAM_RANCHER_DATA_SIZE="{{param-rancher-data-size}}"
export PARAM_RANCHER_SSL_ENABLED="{{param-rancher-ssl-enabled}}"
export PARAM_RANCHER_HOSTNAME="{{param-rancher-hostname}}"

git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
