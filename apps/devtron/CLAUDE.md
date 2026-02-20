# apps/devtron/

Kubernetes-native application lifecycle management platform for CI/CD, GitOps, and deployment automation. **Manifest** deployment method.

## Architecture

- **4-component stack**: Orchestrator (Hyperion) + Dashboard + PostgreSQL 14.9 + NATS 2.9.3
- **Deployment + Recreate**: Single-node K3s VM, all components as Deployments
- **NodePort 30080**: Dashboard (web UI)
- **Images**: `quay.io/devtron/hyperion` (Apache 2.0), `quay.io/devtron/dashboard` (Apache 2.0), `postgres:14.9-alpine` (PostgreSQL License), `nats:2.9.3-alpine` (Apache 2.0)

## Versions

Single version line: 2.0.0 (default). Devtron uses commit-hash-based image tags (e.g., `f0c18f20-280-38148`).

## Parameters

All parameters use `PARAM_*` prefix at runtime. Database and admin passwords are auto-generated in `hooks/pre-install.sh`.

## Manifest Ordering

```
00-secrets.yaml                -> DB + admin credentials
05-configmap.yaml              -> Orchestrator, dashboard, NATS configs
10-postgres-pvc.yaml           -> PostgreSQL data storage
11-nats-pvc.yaml               -> NATS JetStream data
20-postgres-deployment.yaml    -> PostgreSQL 14.9
21-nats-deployment.yaml        -> NATS messaging with JetStream
30-orchestrator-deployment.yaml -> Devtron orchestrator (Hyperion mode)
31-dashboard-deployment.yaml   -> Devtron dashboard (React UI)
40-postgres-service.yaml       -> ClusterIP for PostgreSQL
41-nats-service.yaml           -> ClusterIP for NATS
42-orchestrator-service.yaml   -> ClusterIP for orchestrator
43-dashboard-service.yaml      -> NodePort 30080 (Dashboard)
```

## Health Checks

- PostgreSQL: `pg_isready -U postgres`
- NATS: HTTP monitoring at `:8222`
- Orchestrator: `GET /health` on port 8080
- Dashboard: `GET /` on port 8080
- PVC binding verification

## Access

```bash
# Dashboard (web UI)
curl http://<VM-IP>:30080

# Orchestrator health
curl http://<VM-IP>:30080/orchestrator/health
```

## Networking / Firewall

The following ports must be opened at the firewall or load balancer level:

| Port | Protocol | Purpose | When |
|------|----------|---------|------|
| **443** | HTTPS | Dashboard via Traefik Gateway | SSL enabled |
| **80** | HTTP | Redirects to HTTPS (301) | SSL enabled |
| **30080** | TCP | Dashboard (NodePort) | Always |

## Notes

- This is a simplified single-node deployment for evaluation and small teams
- Some enterprise features (multi-cluster management, CI/CD pipelines) may not function on single-node K3s
- Hyperion mode (lightweight, no CI/CD engine) is used by default
- Images are on `quay.io/devtron/` (not Docker Hub)

## Version Update Procedure

1. Check latest release at https://github.com/devtron-labs/devtron/releases
2. Find image tags in the release's `devtron-bom.yaml` or `devtron-images.txt.source`
3. Update orchestrator tag in `app.yaml` versions and dashboard tag in `31-dashboard-deployment.yaml`
4. Run `make validate && make test-e2e APP=devtron`
