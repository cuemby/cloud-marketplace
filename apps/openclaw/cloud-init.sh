#!/bin/bash
set -euo pipefail

apt-get update -y
apt-get install -y curl git jq

export APP_NAME="openclaw"
export APP_VERSION="{{app-version}}"
export PARAM_OPENCLAW_API_KEY="{{param-openclaw-api-key}}"
export PARAM_OPENCLAW_LLM_PROVIDER="{{param-openclaw-llm-provider}}"
export PARAM_OPENCLAW_DATA_SIZE="{{param-openclaw-data-size}}"
export PARAM_OPENCLAW_SSL_ENABLED="{{param-openclaw-ssl-enabled}}"
export PARAM_OPENCLAW_HOSTNAME="{{param-openclaw-hostname}}"
export ACME_EMAIL="{{param-openclaw-acme-email}}"

git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
