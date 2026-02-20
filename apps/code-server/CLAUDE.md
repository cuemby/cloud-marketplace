# code-server — App-Level CLAUDE.md

## Architecture

- **Type**: Single-tier (browser-based IDE)
- **Components**: code-server (VS Code in the browser)
- **Deploy method**: Manifest (raw K8s YAML + envsubst)
- **Storage**: PVC via `local-path` StorageClass

## Components

| Component | Image | Role |
|-----------|-------|------|
| code-server | `docker.io/codercom/code-server` | VS Code IDE accessible via web browser |

## Parameters

| Parameter | Default | Effect |
|-----------|---------|--------|
| `CODE_SERVER_PASSWORD` | (auto-generated) | Password for web IDE login |
| `CODE_SERVER_DATA_SIZE` | `20Gi` | PVC size for workspace data |

## Health Check

1. HTTP GET `http://localhost:8080/healthz` — code-server health endpoint
2. PVC bound status verification

## Access

| Endpoint | Port | Protocol |
|----------|------|----------|
| Web IDE | 30080 (NodePort) | HTTP |

## Networking / Firewall

The following ports must be opened at the firewall or load balancer level:

| Port | Protocol | Purpose | When |
|------|----------|---------|------|
| **443** | HTTPS | Web UI via Traefik Gateway | SSL enabled |
| **80** | HTTP | Redirects to HTTPS (301) | SSL enabled |
| **30080** | TCP | code-server web IDE (NodePort) | Always |

## Version Update

1. Check available tags at Docker Hub: `codercom/code-server`
2. Update `versions` array in `app.yaml`
3. Run `make validate && make lint && make catalog`
4. Test with `make test-integration` if available

## Notes

- Password authentication is enabled by default via `PASSWORD` env var.
- Workspace data is stored in `/home/coder` inside the container.
- The code-server image runs as UID 1000 (coder user).
- License: MIT (fully open-source).
