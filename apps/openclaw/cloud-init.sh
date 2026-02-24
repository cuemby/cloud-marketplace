#!/bin/bash
set -euo pipefail

apt-get update -y
apt-get install -y curl git jq

export APP_NAME="openclaw"
export APP_VERSION="{{app-version}}"

# LLM provider API keys (set the one matching your provider; the other can be left empty)
export PARAM_OPENCLAW_ANTHROPIC_API_KEY="{{param-openclaw-anthropic-api-key}}"
export PARAM_OPENCLAW_OPENAI_API_KEY="{{param-openclaw-openai-api-key}}"

# SSL
export PARAM_OPENCLAW_SSL_ENABLED="{{param-openclaw-ssl-enabled}}"
export PARAM_OPENCLAW_HOSTNAME="{{param-openclaw-hostname}}"
export PARAM_OPENCLAW_ACME_EMAIL="{{param-openclaw-acme-email}}"

# Optional channel tokens (leave empty to configure later from the dashboard)
export PARAM_OPENCLAW_TELEGRAM_TOKEN="{{param-openclaw-telegram-token}}"
export PARAM_OPENCLAW_DISCORD_TOKEN="{{param-openclaw-discord-token}}"
export PARAM_OPENCLAW_SLACK_BOT_TOKEN="{{param-openclaw-slack-bot-token}}"
export PARAM_OPENCLAW_SLACK_APP_TOKEN="{{param-openclaw-slack-app-token}}"

git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
