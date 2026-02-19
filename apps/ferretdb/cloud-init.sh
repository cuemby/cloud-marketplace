#!/bin/bash
# Bash user-data script for deploying FerretDB via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Passwords are auto-generated if not provided.
#
# VM requirements: 2 CPU, 4 GB RAM, 30 GB disk, Ubuntu 22.04+ recommended.
# Firewall: allow inbound TCP on port 30017 (FerretDB MongoDB-compatible).

set -euo pipefail

# -- Install prerequisites --
apt-get update -y
apt-get install -y curl git jq

# -- Application configuration --
export APP_NAME="ferretdb"
export APP_VERSION="{{app-version}}"

# Credentials (Cuemby Cloud interpolates {{...}}; auto-generated otherwise)
export PARAM_FERRETDB_DB_PASSWORD="{{param-ferretdb-db-password}}"

# Optional parameters (Cuemby Cloud interpolates; defaults applied in pre-install hook)
export PARAM_FERRETDB_DB_DATA_SIZE="{{param-ferretdb-db-data-size}}"

# -- Deploy --
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
