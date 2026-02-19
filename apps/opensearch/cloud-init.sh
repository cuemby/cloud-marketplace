#!/bin/bash
# Bash user-data script for deploying OpenSearch via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Password is auto-generated if not provided.
#
# VM requirements: 4 CPU, 8 GB RAM, 50 GB disk, Ubuntu 22.04+ recommended.
# Firewall: allow inbound TCP on port 30920 (OpenSearch REST API).

set -euo pipefail

# -- Install prerequisites --
apt-get update -y
apt-get install -y curl git jq

# -- Application configuration --
export APP_NAME="opensearch"
export APP_VERSION="{{app-version}}"

# Credentials (Cuemby Cloud interpolates {{...}}; auto-generated otherwise)
export PARAM_OPENSEARCH_PASSWORD="{{param-opensearch-password}}"

# Optional parameters (Cuemby Cloud interpolates; defaults applied in pre-install hook)
export PARAM_OPENSEARCH_CLUSTER_NAME="{{param-opensearch-cluster-name}}"
export PARAM_OPENSEARCH_DATA_SIZE="{{param-opensearch-data-size}}"
export PARAM_OPENSEARCH_JAVA_OPTS="{{param-opensearch-java-opts}}"

# -- Deploy --
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
