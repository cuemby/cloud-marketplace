#!/bin/bash
# Bash user-data script for deploying Neo4j via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Auth password is auto-generated if not provided.
#
# VM requirements: 2 CPU, 4 GB RAM, 30 GB disk, Ubuntu 22.04+ recommended.
# Firewall: allow inbound TCP on ports 30474 (HTTP) and 30687 (Bolt).

set -euo pipefail

# -- Install prerequisites --
apt-get update -y
apt-get install -y curl git jq

# -- Application configuration --
export APP_NAME="neo4j"
export APP_VERSION="{{app-version}}"

# Credentials (Cuemby Cloud interpolates {{...}}; auto-generated otherwise)
export PARAM_NEO4J_AUTH_PASSWORD="{{param-neo4j-auth-password}}"

# Optional parameters (Cuemby Cloud interpolates; defaults applied in pre-install hook)
export PARAM_NEO4J_DATA_SIZE="{{param-neo4j-data-size}}"
export PARAM_NEO4J_HEAP_SIZE="{{param-neo4j-heap-size}}"

# -- Deploy --
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
