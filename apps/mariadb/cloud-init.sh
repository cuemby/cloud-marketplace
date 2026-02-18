#!/bin/bash
# Bash user-data script for deploying MariaDB via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Parameters can be set as environment variables before running this script,
# or they will use the default values shown below.
#
# VM requirements: 1 CPU, 2 GB RAM, 20 GB disk, Ubuntu 22.04 LTS recommended.
# Firewall: allow inbound TCP on port 30307 (MariaDB).

set -euo pipefail

# ── Install prerequisites ────────────────────────────────────────────────────
apt-get update -y
apt-get install -y curl git jq

# ── Application configuration ────────────────────────────────────────────────
export APP_NAME="mariadb"
export APP_VERSION="${APP_VERSION:-25.0.0}"

# Required parameters
export PARAM_MARIADB_ROOT_PASSWORD="${PARAM_MARIADB_ROOT_PASSWORD:?PARAM_MARIADB_ROOT_PASSWORD is required}"

# Optional parameters
export PARAM_MARIADB_USERNAME="${PARAM_MARIADB_USERNAME:-}"
export PARAM_MARIADB_PASSWORD="${PARAM_MARIADB_PASSWORD:-}"
export PARAM_MARIADB_DATABASE="${PARAM_MARIADB_DATABASE:-}"

# ── Deploy ───────────────────────────────────────────────────────────────────
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
