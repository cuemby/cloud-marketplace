# apps/gitea/

Self-hosted Git service using the **manifest** deployment method.

## Architecture

- **Single-tier**: Gitea with embedded SQLite (no external DB)
- **Deployment + Recreate**: Single-node K3s VM
- **NodePort 30300**: External HTTP access (web UI + Git HTTP)
- **NodePort 30022**: External SSH access (Git SSH)
- **Official image**: `gitea/gitea:<version>` (MIT License)

## Versions

Three versions supported: 1.23.7, 1.22.7, 1.21.11.

## Parameters

All parameters use `PARAM_*` prefix at runtime. Only data size is configurable — no passwords needed (SQLite, admin via UI).

## Admin Account

Gitea does NOT support automated admin account creation in this configuration. The admin account is created interactively via Gitea's first-visit install wizard at `http://<VM-IP>:30300`.

## Manifest Ordering

```
05-configmap.yaml            -> App config (DB_TYPE=sqlite3, server settings)
10-gitea-pvc.yaml            -> Data storage (repos, DB, config, SSH keys)
20-gitea-deployment.yaml     -> Gitea Deployment with probes
40-gitea-http-service.yaml   -> NodePort 30300 (HTTP)
41-gitea-ssh-service.yaml    -> NodePort 30022 (SSH)
```

## Health Checks

- `GET /api/healthz` returns 200 when healthy
- PVC binding verification

## Networking / Firewall

The following ports must be opened at the firewall or load balancer level:

| Port | Protocol | Purpose | When |
|------|----------|---------|------|
| **443** | HTTPS | Web UI via Traefik Gateway | SSL enabled |
| **80** | HTTP | Redirects to HTTPS (301) | SSL enabled |
| **30300** | TCP | Web UI + Git HTTP (NodePort) | Always |
| **30022** | TCP | Git SSH (NodePort) | Always |

## Version Update Procedure

1. Check latest release at https://github.com/go-gitea/gitea/releases
2. Verify Docker Hub tag exists: `gitea/gitea:<new>`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make test-e2e APP=gitea`
