#!/bin/bash
# Bash user-data script for deploying InfluxDB via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Parameters can be set as environment variables before running this script,
# or they will use the default values shown below.
#
# VM requirements: 2 CPU, 4 GB RAM, 20 GB disk, Ubuntu 22.04 LTS recommended.
# Firewall: allow inbound TCP on port 30086 (InfluxDB HTTP API).

set -euo pipefail

# ── Install prerequisites ────────────────────────────────────────────────────
apt-get update -y
apt-get install -y curl git jq

# ── Application configuration ────────────────────────────────────────────────
export APP_NAME="influxdb"
export APP_VERSION="${APP_VERSION:-7.1.20}"

# Required parameters
export PARAM_INFLUXDB_ADMIN_PASSWORD="${PARAM_INFLUXDB_ADMIN_PASSWORD:?PARAM_INFLUXDB_ADMIN_PASSWORD is required}"
export PARAM_INFLUXDB_ADMIN_TOKEN="${PARAM_INFLUXDB_ADMIN_TOKEN:?PARAM_INFLUXDB_ADMIN_TOKEN is required}"

# Optional parameters
export PARAM_INFLUXDB_ADMIN_USER="${PARAM_INFLUXDB_ADMIN_USER:-admin}"
export PARAM_INFLUXDB_ADMIN_ORG="${PARAM_INFLUXDB_ADMIN_ORG:-cuemby}"
export PARAM_INFLUXDB_ADMIN_BUCKET="${PARAM_INFLUXDB_ADMIN_BUCKET:-default}"

# ── Deploy ───────────────────────────────────────────────────────────────────
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
