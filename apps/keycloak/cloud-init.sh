#!/bin/bash
# Bash user-data script for deploying Keycloak via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Parameters can be set as environment variables before running this script,
# or they will use the default values shown below.
#
# VM requirements: 2 CPU, 4 GB RAM, 20 GB disk, Ubuntu 22.04 LTS recommended.
# Firewall: allow inbound TCP on port 30880 (HTTP Admin Console).

set -euo pipefail

# ── Install prerequisites ────────────────────────────────────────────────────
apt-get update -y
apt-get install -y curl git jq

# ── Application configuration ────────────────────────────────────────────────
export APP_NAME="keycloak"
export APP_VERSION="${APP_VERSION:-25.2.0}"

# Required parameters
export PARAM_KEYCLOAK_ADMIN_USER="${PARAM_KEYCLOAK_ADMIN_USER:-user}"
export PARAM_KEYCLOAK_ADMIN_PASSWORD="${PARAM_KEYCLOAK_ADMIN_PASSWORD:?PARAM_KEYCLOAK_ADMIN_PASSWORD is required}"
export PARAM_KEYCLOAK_POSTGRES_PASSWORD="${PARAM_KEYCLOAK_POSTGRES_PASSWORD:?PARAM_KEYCLOAK_POSTGRES_PASSWORD is required}"

# ── Deploy ───────────────────────────────────────────────────────────────────
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
