#!/bin/bash
set -euo pipefail

apt-get update -y
apt-get install -y curl git jq

export APP_NAME="code-server"
export APP_VERSION="{{app-version}}"
export PARAM_CODE_SERVER_PASSWORD="{{param-code-server-password}}"
export PARAM_CODE_SERVER_DATA_SIZE="{{param-code-server-data-size}}"
export PARAM_CODE_SERVER_SSL_ENABLED="{{param-code-server-ssl-enabled}}"
export PARAM_CODE_SERVER_HOSTNAME="{{param-code-server-hostname}}"

git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
