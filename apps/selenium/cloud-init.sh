#!/bin/bash
set -euo pipefail

apt-get update -y
apt-get install -y curl git jq

export APP_NAME="selenium"
export APP_VERSION="{{app-version}}"
export PARAM_SELENIUM_CHROME_NODES="{{param-selenium-chrome-nodes}}"
export PARAM_SELENIUM_FIREFOX_NODES="{{param-selenium-firefox-nodes}}"
export PARAM_SELENIUM_SSL_ENABLED="{{param-selenium-ssl-enabled}}"
export PARAM_SELENIUM_HOSTNAME="{{param-selenium-hostname}}"

git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
