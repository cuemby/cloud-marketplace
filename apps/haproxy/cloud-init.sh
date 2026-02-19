#!/bin/bash
set -euo pipefail

apt-get update -y
apt-get install -y curl git jq

export APP_NAME="haproxy"
export APP_VERSION="{{app-version}}"
export PARAM_HAPROXY_STATS_PASSWORD="{{param-haproxy-stats-password}}"
export PARAM_HAPROXY_STATS_USER="{{param-haproxy-stats-user}}"

git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
