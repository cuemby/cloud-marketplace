#!/bin/bash
# Bash user-data script for deploying Redmine via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Parameters can be set as environment variables before running this script,
# or they will use the default values shown below.
#
# VM requirements: 2 CPU, 4 GB RAM, 20 GB disk, Ubuntu 22.04 LTS recommended.
# Firewall: allow inbound TCP on ports 80 (HTTP) and 443 (HTTPS).

set -euo pipefail

# ── Install prerequisites ────────────────────────────────────────────────────
apt-get update -y
apt-get install -y curl git jq

# ── Application configuration ────────────────────────────────────────────────
export APP_NAME="redmine"
export APP_VERSION="${APP_VERSION:-34.0.0}"

# Required parameters
export PARAM_REDMINE_USERNAME="${PARAM_REDMINE_USERNAME:-admin}"
export PARAM_REDMINE_PASSWORD="${PARAM_REDMINE_PASSWORD:?PARAM_REDMINE_PASSWORD is required}"
export PARAM_REDMINE_EMAIL="${PARAM_REDMINE_EMAIL:?PARAM_REDMINE_EMAIL is required}"
export PARAM_REDMINE_MARIADB_ROOT_PASSWORD="${PARAM_REDMINE_MARIADB_ROOT_PASSWORD:?PARAM_REDMINE_MARIADB_ROOT_PASSWORD is required}"
export PARAM_REDMINE_MARIADB_PASSWORD="${PARAM_REDMINE_MARIADB_PASSWORD:?PARAM_REDMINE_MARIADB_PASSWORD is required}"

# SSL parameters (optional — hostname auto-detected via sslip.io if not set)
export PARAM_REDMINE_HOSTNAME="${PARAM_REDMINE_HOSTNAME:-}"
export ACME_EMAIL="${ACME_EMAIL:-${PARAM_REDMINE_EMAIL}}"
export ACME_USE_STAGING="${ACME_USE_STAGING:-false}"

# ── Deploy ───────────────────────────────────────────────────────────────────
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
