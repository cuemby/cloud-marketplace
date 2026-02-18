#!/bin/bash
# Bash user-data script for deploying PostgreSQL via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Password is auto-generated if not provided.
#
# VM requirements: 2 CPU, 4 GB RAM, 30 GB disk, Ubuntu 22.04+ recommended.
# Firewall: allow inbound TCP on port 30432 (PostgreSQL).

set -euo pipefail

# -- Install prerequisites --
apt-get update -y
apt-get install -y curl git jq

# -- Application configuration --
export APP_NAME="postgresql"
export APP_VERSION="{{app-version}}"

# Credentials (Cuemby Cloud interpolates {{...}}; auto-generated otherwise)
export PARAM_POSTGRES_PASSWORD="{{param-postgres-password}}"

# Optional parameters (Cuemby Cloud interpolates; defaults applied in pre-install hook)
export PARAM_POSTGRES_USER="{{param-postgres-user}}"
export PARAM_POSTGRES_DB="{{param-postgres-db}}"
export PARAM_POSTGRESQL_DATA_SIZE="{{param-postgresql-data-size}}"
export PARAM_POSTGRESQL_MAX_CONNECTIONS="{{param-postgresql-max-connections}}"
export PARAM_POSTGRESQL_SHARED_BUFFERS="{{param-postgresql-shared-buffers}}"
export PARAM_POSTGRESQL_WORK_MEM="{{param-postgresql-work-mem}}"

# -- Deploy --
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
