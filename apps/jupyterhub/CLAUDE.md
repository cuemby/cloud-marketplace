# apps/jupyterhub/

JupyterHub application for the Cuemby Cloud Marketplace.

## Overview

Multi-user Jupyter notebook server deployed on single-node K3s via Bitnami Helm chart.
SSL-enabled with Gateway API. No bundled database. Category: ai-ml.

## Architecture

- **Hub**: Central process that manages authentication and spawns single-user servers
- **Proxy**: Routes traffic to hub and individual notebook servers (proxy-public service)
- **Single-user pods**: Spawned dynamically on user login (one pod per user)

## Key Files

- `app.yaml` — Marketplace metadata, parameters, helmMappings
- `chart/` — Wrapper Helm chart (depends on bitnami/jupyterhub 10.0.5)
- `hooks/pre-install.sh` — SSL/Gateway API setup (targets proxy-public service, port 80)
- `hooks/post-install.sh` — Post-deploy logging
- `hooks/healthcheck.sh` — HTTPS check at /hub/login with 300s timeout
- `cloud-init.sh` — Bash user-data for VM provisioning

## Conventions

- SSL routes through `jupyterhub-proxy-public` service on port 80
- Health check endpoint is `/hub/login` (not `/health` or `/api`)
- Single-user pods spawn on first login — allow extra startup time
- No bundled DB — JupyterHub uses SQLite by default
