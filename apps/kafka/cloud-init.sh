#!/bin/bash
# Bash user-data script for deploying Apache Kafka via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Cluster ID is auto-generated if not provided.
#
# VM requirements: 4 CPU, 8 GB RAM, 50 GB disk, Ubuntu 22.04+ recommended.
# Firewall: allow inbound TCP on port 30909 (Kafka broker).

set -euo pipefail

# -- Install prerequisites --
apt-get update -y
apt-get install -y curl git jq

# -- Application configuration --
export APP_NAME="kafka"
export APP_VERSION="{{app-version}}"

# Optional parameters (Cuemby Cloud interpolates; defaults applied in pre-install hook)
export PARAM_KAFKA_CLUSTER_ID="{{param-kafka-cluster-id}}"
export PARAM_KAFKA_DATA_SIZE="{{param-kafka-data-size}}"
export PARAM_KAFKA_HEAP_OPTS="{{param-kafka-heap-opts}}"

# -- Deploy --
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
