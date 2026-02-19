#!/bin/bash
set -euo pipefail

apt-get update -y
apt-get install -y curl git jq

export APP_NAME="docker-registry"
export APP_VERSION="{{app-version}}"
export PARAM_REGISTRY_DATA_SIZE="{{param-registry-data-size}}"
export PARAM_REGISTRY_HTTP_SECRET="{{param-registry-http-secret}}"

git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
