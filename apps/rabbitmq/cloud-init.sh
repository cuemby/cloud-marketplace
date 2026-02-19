#!/bin/bash
# Bash user-data script for deploying RabbitMQ via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Admin password is auto-generated if not provided.
#
# VM requirements: 2 CPU, 4 GB RAM, 20 GB disk, Ubuntu 22.04+ recommended.
# Firewall: allow inbound TCP on ports 30672 (AMQP) and 31672 (Management UI).

set -euo pipefail

# -- Install prerequisites --
apt-get update -y
apt-get install -y curl git jq

# -- Application configuration --
export APP_NAME="rabbitmq"
export APP_VERSION="{{app-version}}"

# Credentials (Cuemby Cloud interpolates {{...}}; auto-generated otherwise)
export PARAM_RABBITMQ_DEFAULT_PASS="{{param-rabbitmq-default-pass}}"

# Optional parameters (Cuemby Cloud interpolates; defaults applied in pre-install hook)
export PARAM_RABBITMQ_DEFAULT_USER="{{param-rabbitmq-default-user}}"
export PARAM_RABBITMQ_DATA_SIZE="{{param-rabbitmq-data-size}}"

# -- Deploy --
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
