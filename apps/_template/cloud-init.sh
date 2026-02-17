#!/bin/bash
# Bash user-data script for deploying APPNAME via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
# Replace CHANGE_ME values with your own, then pass this script as user-data when creating a VM.

set -euo pipefail

# ── Install prerequisites ────────────────────────────────────────────────────
apt-get update -y
apt-get install -y curl git jq

# ── Application configuration ────────────────────────────────────────────────
export APP_NAME="APPNAME"
export APP_VERSION="CHANGE_ME"
export PARAM_EXAMPLE_PARAM="CHANGE_ME"

# ── Deploy ───────────────────────────────────────────────────────────────────
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
