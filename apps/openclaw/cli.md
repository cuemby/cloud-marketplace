# OpenClaw — Cloud-Init Bash Script

```bash
#!/bin/bash
# Bash user-data script for deploying OpenClaw via Cuemby Cloud Marketplace.
# Use this on providers that don't support cloud-init YAML (e.g., raw bash user-data).
#
# VM requirements: 2 CPU, 4 GB RAM, 20 GB disk, Ubuntu 22.04+ recommended.
# Firewall: allow inbound TCP on ports 80, 443 (HTTPS) and 30789 (WebSocket).

set -euo pipefail

# -- Install prerequisites --
apt-get update -y
apt-get install -y curl git jq

# -- Application configuration --
export APP_NAME="openclaw"
export APP_VERSION="{{app-version}}"

# Credentials
export PARAM_OPENCLAW_API_KEY="{{param-openclaw-api-key}}"

# Optional parameters (defaults applied in pre-install hook)
export PARAM_OPENCLAW_LLM_PROVIDER="{{param-openclaw-llm-provider}}"
export PARAM_OPENCLAW_DATA_SIZE="{{param-openclaw-data-size}}"
export PARAM_OPENCLAW_SSL_ENABLED="${PARAM_OPENCLAW_SSL_ENABLED:-true}"
export PARAM_OPENCLAW_HOSTNAME="{{param-openclaw-hostname}}"
export ACME_EMAIL="${ACME_EMAIL:-me@cuemby.com}"

# -- Deploy --
git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
/opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log
```
