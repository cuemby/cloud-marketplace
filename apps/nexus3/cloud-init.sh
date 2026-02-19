#!/bin/bash
set -euo pipefail

apt-get update -y
apt-get install -y curl git jq

export APP_NAME="nexus3"
export APP_VERSION="{{app-version}}"
export PARAM_NEXUS_DATA_SIZE="{{param-nexus-data-size}}"

git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
