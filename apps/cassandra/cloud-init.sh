#!/bin/bash
# Bash user-data script for deploying Apache Cassandra via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Password is auto-generated if not provided.
#
# VM requirements: 4 CPU, 8 GB RAM, 50 GB disk, Ubuntu 22.04+ recommended.
# Firewall: allow inbound TCP on port 30942 (CQL).

set -euo pipefail

# -- Install prerequisites --
apt-get update -y
apt-get install -y curl git jq

# -- Application configuration --
export APP_NAME="cassandra"
export APP_VERSION="{{app-version}}"

# Credentials (Cuemby Cloud interpolates {{...}}; auto-generated otherwise)
export PARAM_CASSANDRA_PASSWORD="{{param-cassandra-password}}"

# Optional parameters (Cuemby Cloud interpolates; defaults applied in pre-install hook)
export PARAM_CASSANDRA_CLUSTER_NAME="{{param-cassandra-cluster-name}}"
export PARAM_CASSANDRA_DATA_SIZE="{{param-cassandra-data-size}}"
export PARAM_CASSANDRA_MAX_HEAP_SIZE="{{param-cassandra-max-heap-size}}"
export PARAM_CASSANDRA_HEAP_NEWSIZE="{{param-cassandra-heap-newsize}}"
export PARAM_CASSANDRA_NUM_TOKENS="{{param-cassandra-num-tokens}}"

# -- Deploy --
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
