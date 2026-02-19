#!/bin/bash
# Bash user-data script for deploying SonarQube via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Passwords are auto-generated if not provided.
# SonarQube requires vm.max_map_count=524288 and fs.file-max=131072.
#
# VM requirements: 4 CPU, 8 GB RAM, 50 GB disk, Ubuntu 22.04+ recommended.
# Firewall: allow inbound TCP on port 30900 (SonarQube web UI).

set -euo pipefail

# -- Install prerequisites --
apt-get update -y
apt-get install -y curl git jq

# -- Kernel tuning for SonarQube (Elasticsearch requires these) --
cat > /etc/sysctl.d/99-sonarqube.conf <<'SYSCTL'
vm.max_map_count=524288
fs.file-max=131072
SYSCTL
sysctl --system

# -- Application configuration --
export APP_NAME="sonarqube"
export APP_VERSION="{{app-version}}"

# Credentials (Cuemby Cloud interpolates {{...}}; auto-generated otherwise)
export PARAM_SONARQUBE_DB_PASSWORD="{{param-sonarqube-db-password}}"

# Optional parameters (Cuemby Cloud interpolates; defaults applied in pre-install hook)
export PARAM_SONARQUBE_DB_DATA_SIZE="{{param-sonarqube-db-data-size}}"
export PARAM_SONARQUBE_DATA_SIZE="{{param-sonarqube-data-size}}"

# -- Deploy --
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
