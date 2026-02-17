#!/bin/bash
# Bash user-data script for deploying Redis via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Parameters can be set as environment variables before running this script,
# or they will use the default values shown below.
#
# VM requirements: 1 CPU, 2 GB RAM, 10 GB disk, Ubuntu 22.04 LTS recommended.
# Firewall: allow inbound TCP on port 30379 (Redis).

set -euo pipefail

# ── Install prerequisites ────────────────────────────────────────────────────
apt-get update -y
apt-get install -y curl git jq

# ── Application configuration ────────────────────────────────────────────────
export APP_NAME="redis"
export APP_VERSION="${APP_VERSION:-25.2.0}"

# Required parameters
export PARAM_REDIS_PASSWORD="${PARAM_REDIS_PASSWORD:?PARAM_REDIS_PASSWORD is required}"

# ── Deploy ───────────────────────────────────────────────────────────────────
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
