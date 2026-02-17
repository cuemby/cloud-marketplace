#!/bin/bash
# Bash user-data script for deploying PostgreSQL via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Parameters can be set as environment variables before running this script,
# or they will use the default values shown below.
#
# VM requirements: 1 CPU, 2 GB RAM, 20 GB disk, Ubuntu 22.04 LTS recommended.
# Firewall: allow inbound TCP on port 30432 (PostgreSQL).

set -euo pipefail

# ── Install prerequisites ────────────────────────────────────────────────────
apt-get update -y
apt-get install -y curl git jq

# ── Application configuration ────────────────────────────────────────────────
export APP_NAME="postgresql"
export APP_VERSION="${APP_VERSION:-18.3.0}"

# Required parameters
export PARAM_POSTGRES_PASSWORD="${PARAM_POSTGRES_PASSWORD:?PARAM_POSTGRES_PASSWORD is required}"

# Optional parameters
export PARAM_POSTGRES_USERNAME="${PARAM_POSTGRES_USERNAME:-}"
export PARAM_POSTGRES_USER_PASSWORD="${PARAM_POSTGRES_USER_PASSWORD:-}"
export PARAM_POSTGRES_DATABASE="${PARAM_POSTGRES_DATABASE:-}"

# ── Deploy ───────────────────────────────────────────────────────────────────
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
