#!/bin/bash
# Bash user-data script for deploying Odoo via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Passwords are auto-generated if not provided.
#
# VM requirements: 2 CPU, 4 GB RAM, 30 GB disk, Ubuntu 22.04+ recommended.
# Firewall: allow inbound TCP on port 30069 (Odoo web UI).

set -euo pipefail

# -- Install prerequisites --
apt-get update -y
apt-get install -y curl git jq

# -- Application configuration --
export APP_NAME="odoo"
export APP_VERSION="{{app-version}}"

# Credentials (Cuemby Cloud interpolates {{...}}; auto-generated otherwise)
export PARAM_ODOO_DB_PASSWORD="{{param-odoo-db-password}}"
export PARAM_ODOO_ADMIN_PASSWORD="{{param-odoo-admin-password}}"

# Optional parameters (Cuemby Cloud interpolates; defaults applied in pre-install hook)
export PARAM_ODOO_DB_DATA_SIZE="{{param-odoo-db-data-size}}"
export PARAM_ODOO_DATA_SIZE="{{param-odoo-data-size}}"

# -- Deploy --
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
