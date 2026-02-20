# Portainer CE — App-Level CLAUDE.md

## Architecture

- **Type**: Single-tier (container management UI)
- **Components**: Portainer CE (web-based container management)
- **Deploy method**: Manifest (raw K8s YAML + envsubst)
- **Storage**: PVC via `local-path` StorageClass

## Components

| Component | Image | Role |
|-----------|-------|------|
| Portainer CE | `docker.io/portainer/portainer-ce` | Container management web UI for Docker, Swarm, and Kubernetes |

## Parameters

| Parameter | Default | Effect |
|-----------|---------|--------|
| `PORTAINER_DATA_SIZE` | `5Gi` | PVC size for Portainer data (settings, users, stacks) |

## Health Check

1. HTTP GET `http://localhost:9000/api/status` — Portainer API responding
2. PVC bound status verification

## Networking / Firewall

The following ports must be opened at the firewall or load balancer level:

| Port | Protocol | Purpose | When |
|------|----------|---------|------|
| **443** | HTTPS | Web UI via Traefik Gateway | SSL enabled |
| **80** | HTTP | Redirects to HTTPS (301) | SSL enabled |
| **30900** | TCP | Portainer web UI (NodePort) | Always |

## Access

| Endpoint | Port | Protocol |
|----------|------|----------|
| Web UI | 30900 (NodePort) | HTTP |

## Version Update

1. Check available tags at Docker Hub: `portainer/portainer-ce`
2. Update `versions` array in `app.yaml`
3. Run `make validate && make lint && make catalog`
4. Test with `make test-integration` if available

## Notes

- No pre-configured credentials; admin account is created on first web UI login.
- Portainer auto-detects the local Kubernetes environment.
- License: Zlib (fully open-source).
