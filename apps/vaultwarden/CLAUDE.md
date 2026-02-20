# Vaultwarden — App-Level CLAUDE.md

## Architecture

- **Type**: Single-tier (password manager server)
- **Components**: Vaultwarden (Bitwarden-compatible server)
- **Deploy method**: Manifest (raw K8s YAML + envsubst)
- **Storage**: PVC via `local-path` StorageClass

## Components

| Component | Image | Role |
|-----------|-------|------|
| Vaultwarden | `docker.io/vaultwarden/server` | Bitwarden-compatible password manager server |

## Parameters

| Parameter | Default | Effect |
|-----------|---------|--------|
| `VAULTWARDEN_ADMIN_TOKEN` | (auto-generated) | Token for `/admin` panel access |
| `VAULTWARDEN_DATA_SIZE` | `5Gi` | PVC size for SQLite database and attachments |

## Health Check

1. HTTP GET `http://localhost:80/alive` — Vaultwarden alive endpoint
2. PVC bound status verification

## Access

| Endpoint | Port | Protocol |
|----------|------|----------|
| Web Vault | 30080 (NodePort) | HTTP |
| Admin Panel | 30080/admin (NodePort) | HTTP |

## Networking / Firewall

The following ports must be opened at the firewall or load balancer level:

| Port | Protocol | Purpose | When |
|------|----------|---------|------|
| **443** | HTTPS | Web UI via Traefik Gateway | SSL enabled |
| **80** | HTTP | Redirects to HTTPS (301) | SSL enabled |
| **30080** | TCP | Vaultwarden web vault (NodePort) | Always |

## Version Update

1. Check available tags at Docker Hub: `vaultwarden/server`
2. Update `versions` array in `app.yaml`
3. Run `make validate && make lint && make catalog`
4. Test with `make test-integration` if available

## Notes

- Vaultwarden uses SQLite for storage (no external database required).
- Data is stored in `/data` inside the container (includes SQLite DB, attachments, icon cache).
- Admin panel is accessible at `/admin` with the configured admin token.
- License: AGPLv3 (open-source, Bitwarden-compatible).
