#!/bin/bash
# Bash user-data script for deploying Mastodon via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Parameters can be set as environment variables before running this script,
# or they will use the default values shown below.
#
# VM requirements: 2 CPU, 4 GB RAM, 30 GB disk, Ubuntu 22.04 LTS recommended.
# Firewall: allow inbound TCP on ports 80 (HTTP) and 443 (HTTPS).

set -euo pipefail

# -- Install prerequisites ----------------------------------------------------
apt-get update -y
apt-get install -y curl git jq

# -- Application configuration ------------------------------------------------
export APP_NAME="mastodon"
export APP_VERSION="${APP_VERSION:-14.0.0}"

# Required parameters
export PARAM_MASTODON_ADMIN_EMAIL="${PARAM_MASTODON_ADMIN_EMAIL:?PARAM_MASTODON_ADMIN_EMAIL is required}"
export PARAM_MASTODON_ADMIN_PASSWORD="${PARAM_MASTODON_ADMIN_PASSWORD:?PARAM_MASTODON_ADMIN_PASSWORD is required}"
export PARAM_MASTODON_POSTGRES_PASSWORD="${PARAM_MASTODON_POSTGRES_PASSWORD:?PARAM_MASTODON_POSTGRES_PASSWORD is required}"
export PARAM_MASTODON_REDIS_PASSWORD="${PARAM_MASTODON_REDIS_PASSWORD:?PARAM_MASTODON_REDIS_PASSWORD is required}"
export PARAM_MASTODON_ELASTICSEARCH_PASSWORD="${PARAM_MASTODON_ELASTICSEARCH_PASSWORD:?PARAM_MASTODON_ELASTICSEARCH_PASSWORD is required}"

# SSL parameters (optional -- hostname auto-detected via sslip.io if not set)
export PARAM_MASTODON_HOSTNAME="${PARAM_MASTODON_HOSTNAME:-}"
export ACME_EMAIL="${ACME_EMAIL:-${PARAM_MASTODON_ADMIN_EMAIL}}"
export ACME_USE_STAGING="${ACME_USE_STAGING:-false}"

# -- Deploy --------------------------------------------------------------------
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
