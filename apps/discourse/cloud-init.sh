#!/bin/bash
# Bash user-data script for deploying Discourse via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Parameters can be set as environment variables before running this script,
# or they will use the default values shown below.
#
# VM requirements: 2 CPU, 4 GB RAM, 20 GB disk, Ubuntu 22.04 LTS recommended.
# Firewall: allow inbound TCP on ports 80 (HTTP) and 443 (HTTPS).

set -euo pipefail

# -- Install prerequisites ----------------------------------------------------
apt-get update -y
apt-get install -y curl git jq

# -- Application configuration ------------------------------------------------
export APP_NAME="discourse"
export APP_VERSION="${APP_VERSION:-17.0.1}"

# Required parameters
export PARAM_DISCOURSE_EMAIL="${PARAM_DISCOURSE_EMAIL:?PARAM_DISCOURSE_EMAIL is required}"
export PARAM_DISCOURSE_PASSWORD="${PARAM_DISCOURSE_PASSWORD:?PARAM_DISCOURSE_PASSWORD is required}"
export PARAM_DISCOURSE_POSTGRES_PASSWORD="${PARAM_DISCOURSE_POSTGRES_PASSWORD:?PARAM_DISCOURSE_POSTGRES_PASSWORD is required}"
export PARAM_DISCOURSE_REDIS_PASSWORD="${PARAM_DISCOURSE_REDIS_PASSWORD:?PARAM_DISCOURSE_REDIS_PASSWORD is required}"

# Optional parameters
export PARAM_DISCOURSE_USERNAME="${PARAM_DISCOURSE_USERNAME:-admin}"
export PARAM_DISCOURSE_SITE_NAME="${PARAM_DISCOURSE_SITE_NAME:-My Discourse}"

# SSL parameters (optional -- hostname auto-detected via sslip.io if not set)
export PARAM_DISCOURSE_HOSTNAME="${PARAM_DISCOURSE_HOSTNAME:-}"
export ACME_EMAIL="${ACME_EMAIL:-${PARAM_DISCOURSE_EMAIL}}"
export ACME_USE_STAGING="${ACME_USE_STAGING:-false}"

# -- Deploy --------------------------------------------------------------------
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
