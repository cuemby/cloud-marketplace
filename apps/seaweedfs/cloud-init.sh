#!/bin/bash
set -euo pipefail

apt-get update -y
apt-get install -y curl git jq

export APP_NAME="seaweedfs"
export APP_VERSION="{{app-version}}"
export PARAM_SEAWEEDFS_DATA_SIZE="{{param-seaweedfs-data-size}}"
export PARAM_SEAWEEDFS_VOLUME_SIZE_LIMIT="{{param-seaweedfs-volume-size-limit}}"
export PARAM_SEAWEEDFS_SSL_ENABLED="{{param-seaweedfs-ssl-enabled}}"
export PARAM_SEAWEEDFS_HOSTNAME="{{param-seaweedfs-hostname}}"

git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
