#!/bin/bash
# Bash user-data script for deploying MLflow via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Database password is auto-generated if not provided.
#
# VM requirements: 2 CPU, 4 GB RAM, 30 GB disk, Ubuntu 22.04+ recommended.
# Firewall: allow inbound TCP on port 30500 (MLflow web UI).

set -euo pipefail

# -- Install prerequisites --
apt-get update -y
apt-get install -y curl git jq

# -- Application configuration --
export APP_NAME="mlflow"
export APP_VERSION="{{app-version}}"

# Credentials (Cuemby Cloud interpolates {{...}}; auto-generated otherwise)
export PARAM_MLFLOW_DB_PASSWORD="{{param-mlflow-db-password}}"

# Optional parameters (Cuemby Cloud interpolates; defaults applied in pre-install hook)
export PARAM_MLFLOW_DB_DATA_SIZE="{{param-mlflow-db-data-size}}"
export PARAM_MLFLOW_ARTIFACT_SIZE="{{param-mlflow-artifact-size}}"

# -- Deploy --
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
