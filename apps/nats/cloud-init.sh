#!/bin/bash
# Bash user-data script for deploying NATS via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Parameters can be set as environment variables before running this script,
# or they will use the default values shown below.
#
# VM requirements: 1 CPU, 1 GB RAM, 5 GB disk, Ubuntu 22.04 LTS recommended.
# Firewall: allow inbound TCP on port 30222 (NATS client).

set -euo pipefail

# ── Install prerequisites ────────────────────────────────────────────────────
apt-get update -y
apt-get install -y curl git jq

# ── Application configuration ────────────────────────────────────────────────
export APP_NAME="nats"
export APP_VERSION="${APP_VERSION:-9.0.28}"

# Optional parameters
export PARAM_NATS_PASSWORD="${PARAM_NATS_PASSWORD:-}"

# ── Deploy ───────────────────────────────────────────────────────────────────
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
