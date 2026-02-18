#!/bin/bash
# Bash user-data script for deploying ClickHouse via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Parameters can be set as environment variables before running this script,
# or they will use the default values shown below.
#
# VM requirements: 2 CPU, 4 GB RAM, 30 GB disk, Ubuntu 22.04 LTS recommended.
# Firewall: allow inbound TCP on ports 30123 (HTTP) and 30901 (Native).

set -euo pipefail

# -- Install prerequisites ----------------------------------------------------
apt-get update -y
apt-get install -y curl git jq

# -- Application configuration ------------------------------------------------
export APP_NAME="clickhouse"
export APP_VERSION="${APP_VERSION:-9.4.4}"

# Required parameters
export PARAM_CLICKHOUSE_ADMIN_PASSWORD="${PARAM_CLICKHOUSE_ADMIN_PASSWORD:?PARAM_CLICKHOUSE_ADMIN_PASSWORD is required}"

# -- Deploy --------------------------------------------------------------------
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
