# apps/twenty/

Open-source CRM alternative to Salesforce with modern UX, contact management, pipeline tracking, and workflow automation. **Manifest** deployment method.

## Architecture

- **3-component stack**: Twenty CRM app + PostgreSQL 16 + Redis 7
- **Deployment + Recreate**: Single-node K3s VM, all components as Deployments
- **NodePort 30080**: External access via HTTP (Twenty web UI on port 3000)
- **Images**: `twentycrm/twenty` (AGPL-3.0), `postgres:16-alpine` (PostgreSQL License), `redis:7-alpine` (BSD-3-Clause)

## Versions

Single version supported: 1.18.1 (default).

## Parameters

All parameters use `PARAM_*` prefix at runtime. App secret and DB password are auto-generated in `hooks/pre-install.sh`.

## Manifest Ordering

```
00-secrets.yaml              -> DB credentials + app encryption secret
10-postgres-pvc.yaml         -> PostgreSQL data storage
11-twenty-pvc.yaml           -> Twenty file uploads storage
20-postgres-deployment.yaml  -> PostgreSQL 16 (alpine)
21-redis-deployment.yaml     -> Redis 7 (alpine, 256MB maxmemory)
30-twenty-deployment.yaml    -> Twenty app (with wait-for-postgres + wait-for-redis inits)
40-postgres-service.yaml     -> ClusterIP for PostgreSQL
41-redis-service.yaml        -> ClusterIP for Redis
42-twenty-service.yaml       -> NodePort 30080
43-twenty-http-service.yaml  -> ClusterIP port 80 -> 3000 (for SSL/Gateway)
```

## Health Checks

- PostgreSQL: `pg_isready -U twenty -d default` (exec probe)
- Redis: `redis-cli ping | grep -q PONG` (exec probe)
- Twenty: HTTP GET `http://localhost:3000/healthz` (startup/liveness/readiness)
- PVC binding verification

## Networking / Firewall

The following ports must be opened at the firewall or load balancer level:

| Port | Protocol | Purpose | When |
|------|----------|---------|------|
| **443** | HTTPS | Web UI via Traefik Gateway | SSL enabled |
| **80** | HTTP | Redirects to HTTPS (301) | SSL enabled |
| **30080** | TCP | Twenty web UI (NodePort) | Always |

## Access

```bash
# Web UI
http://<VM-IP>:30080
```

## Version Update Procedure

1. Check latest release at https://github.com/twentyhq/twenty/releases
2. Verify Docker Hub tag exists: `twentycrm/twenty:v<new>`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make test-e2e APP=twenty`
