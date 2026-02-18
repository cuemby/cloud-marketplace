#!/bin/bash
# Bash user-data script for deploying phpMyAdmin via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Parameters can be set as environment variables before running this script,
# or they will use the default values shown below.
#
# VM requirements: 1 CPU, 1 GB RAM, 5 GB disk, Ubuntu 22.04 LTS recommended.
# Firewall: allow inbound TCP on ports 80 (HTTP) and 443 (HTTPS).

set -euo pipefail

# ── Install prerequisites ────────────────────────────────────────────────────
apt-get update -y
apt-get install -y curl git jq

# ── Application configuration ────────────────────────────────────────────────
export APP_NAME="phpmyadmin"
export APP_VERSION="${APP_VERSION:-20.0.0}"

# Required parameters
export PARAM_PHPMYADMIN_DB_HOST="${PARAM_PHPMYADMIN_DB_HOST:?PARAM_PHPMYADMIN_DB_HOST is required}"

# Optional parameters
export PARAM_PHPMYADMIN_DB_PORT="${PARAM_PHPMYADMIN_DB_PORT:-3306}"

# SSL parameters (optional — hostname auto-detected via sslip.io if not set)
export PARAM_PHPMYADMIN_HOSTNAME="${PARAM_PHPMYADMIN_HOSTNAME:-}"
export ACME_EMAIL="${ACME_EMAIL:?ACME_EMAIL is required for SSL}"
export ACME_USE_STAGING="${ACME_USE_STAGING:-false}"

# ── Deploy ───────────────────────────────────────────────────────────────────
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
