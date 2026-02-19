#!/bin/bash
# Bash user-data script for deploying CouchDB via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Password is auto-generated if not provided.
#
# VM requirements: 2 CPU, 4 GB RAM, 30 GB disk, Ubuntu 22.04+ recommended.
# Firewall: allow inbound TCP on port 30594 (CouchDB).

set -euo pipefail

# -- Install prerequisites --
apt-get update -y
apt-get install -y curl git jq

# -- Application configuration --
export APP_NAME="couchdb"
export APP_VERSION="{{app-version}}"

# Credentials (Cuemby Cloud interpolates {{...}}; auto-generated otherwise)
export PARAM_COUCHDB_PASSWORD="{{param-couchdb-password}}"

# Optional parameters (Cuemby Cloud interpolates; defaults applied in pre-install hook)
export PARAM_COUCHDB_USER="{{param-couchdb-user}}"
export PARAM_COUCHDB_DATA_SIZE="{{param-couchdb-data-size}}"

# -- Deploy --
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
