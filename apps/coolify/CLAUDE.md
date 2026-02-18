# apps/coolify/

Self-hosted PaaS (Platform as a Service) using the **manifest** deployment method.

## Architecture

- **4-component stack**: Coolify app + PostgreSQL 15 + Redis 7 + Soketi (WebSocket)
- **Deployment + Recreate**: Single-node K3s VM, all components as Deployments
- **NodePort 30800**: External access to Coolify web UI
- **hostPort 80/443**: Coolify's built-in Traefik serves deployed apps on standard HTTP/HTTPS ports
- **Docker daemon**: Installed alongside K3s via pre-install hook; Coolify manages user-deployed apps via Docker socket mount
- **Images**: `ghcr.io/coollabsio/coolify` (Apache 2.0), `postgres:15-alpine`, `redis:7-alpine`, `quay.io/soketi/soketi:1.6-16-debian`

## Version

Single version: `latest` tag. Coolify is a PaaS tool — users want the latest features and security fixes. No version pinning.

## Parameters

All parameters use `PARAM_*` prefix at runtime. Credentials (DB password, Redis password, APP_KEY, Pusher key/secret) are auto-generated in `hooks/pre-install.sh`.

## Docker Dependency

Coolify manages user-deployed applications via Docker. The pre-install hook installs Docker Engine on the VM using the official get.docker.com script. The Docker socket (`/var/run/docker.sock`) is mounted into the Coolify pod as a hostPath volume. K3s uses containerd — Docker and K3s coexist independently.

## Admin Account

Coolify does NOT support automated admin account creation. The admin account is created interactively via Coolify's first-visit registration UI at `http://<VM-IP>:30800`.

## Manifest Ordering

```text
00-secrets.yaml              -> DB + app credentials (dual secret pattern)
05-configmap.yaml            -> App config (env, PHP, Pusher host)
10-postgres-pvc.yaml         -> PostgreSQL data storage
11-redis-pvc.yaml            -> Redis data storage
12-coolify-pvc.yaml          -> Coolify app data (SSH keys, config)
20-postgres-deployment.yaml  -> PostgreSQL 15
21-redis-deployment.yaml     -> Redis 7 (with password auth)
22-soketi-deployment.yaml    -> Soketi WebSocket server
30-coolify-deployment.yaml   -> Coolify app (with Docker socket + hostPort)
40-postgres-service.yaml     -> ClusterIP for PostgreSQL
41-redis-service.yaml        -> ClusterIP for Redis
42-soketi-service.yaml       -> ClusterIP for Soketi
43-coolify-service.yaml      -> NodePort 30800 for UI
```

## Health Checks

- PostgreSQL: `pg_isready -U coolify`
- Coolify HTTP: `curl http://localhost:8080` returns 200/301/302 (container listens on 8080 internally)
- PVC binding verification

## Version Update Procedure

1. Check latest release at https://github.com/coollabsio/coolify/releases
2. Coolify uses `latest` tag — no version update needed in app.yaml
3. Users get updates by redeploying or pulling the latest image
