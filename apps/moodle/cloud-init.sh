#!/bin/bash
# Bash user-data script for deploying Moodle via Cuemby Cloud Marketplace.
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
export APP_NAME="moodle"
export APP_VERSION="${APP_VERSION:-28.0.0}"

# Required parameters
export PARAM_MOODLE_USERNAME="${PARAM_MOODLE_USERNAME:-admin}"
export PARAM_MOODLE_PASSWORD="${PARAM_MOODLE_PASSWORD:?PARAM_MOODLE_PASSWORD is required}"
export PARAM_MOODLE_EMAIL="${PARAM_MOODLE_EMAIL:?PARAM_MOODLE_EMAIL is required}"
export PARAM_MOODLE_MARIADB_ROOT_PASSWORD="${PARAM_MOODLE_MARIADB_ROOT_PASSWORD:?PARAM_MOODLE_MARIADB_ROOT_PASSWORD is required}"
export PARAM_MOODLE_MARIADB_PASSWORD="${PARAM_MOODLE_MARIADB_PASSWORD:?PARAM_MOODLE_MARIADB_PASSWORD is required}"

# SSL parameters (optional — hostname auto-detected via sslip.io if not set)
export PARAM_MOODLE_HOSTNAME="${PARAM_MOODLE_HOSTNAME:-}"
export ACME_EMAIL="${ACME_EMAIL:-${PARAM_MOODLE_EMAIL}}"
export ACME_USE_STAGING="${ACME_USE_STAGING:-false}"

# ── Deploy ───────────────────────────────────────────────────────────────────
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
