#!/bin/bash
# Bash user-data script for deploying Jaeger via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# Jaeger uses in-memory storage — no database parameters required.
# SSL is enabled by default with automatic hostname detection via sslip.io.
#
# VM requirements: 2 CPU, 4 GB RAM, 10 GB disk, Ubuntu 22.04 LTS recommended.
# Firewall: allow inbound TCP on ports 80 (HTTP), 443 (HTTPS), and 31468 (Collector gRPC).

set -euo pipefail

# ── Install prerequisites ────────────────────────────────────────────────────
apt-get update -y
apt-get install -y curl git jq

# ── Application configuration ────────────────────────────────────────────────
export APP_NAME="jaeger"
export APP_VERSION="${APP_VERSION:-6.0.5}"

# SSL parameters (optional — hostname auto-detected via sslip.io if not set)
export PARAM_JAEGER_HOSTNAME="${PARAM_JAEGER_HOSTNAME:-}"
export ACME_EMAIL="${ACME_EMAIL:?ACME_EMAIL is required for SSL}"
export ACME_USE_STAGING="${ACME_USE_STAGING:-false}"

# ── Deploy ───────────────────────────────────────────────────────────────────
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
