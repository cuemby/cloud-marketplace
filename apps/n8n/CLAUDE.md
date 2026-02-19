# apps/n8n/

Extendable workflow automation platform with 400+ integrations. **Manifest** deployment method.

## Architecture

- **2-component stack**: n8n app + PostgreSQL 17.8
- **Deployment + Recreate**: Single-node K3s VM, all components as Deployments
- **NodePort 30080**: External access via HTTP (n8n web UI)
- **Images**: `docker.io/n8nio/n8n` (Sustainable Use License), `postgres:17.8-alpine` (PostgreSQL License)

## Versions

Three versions supported: 2.9.0 (default), 2.8.3, 2.7.5.

## Parameters

All parameters use `PARAM_*` prefix at runtime. Database password and encryption key are auto-generated in `hooks/pre-install.sh`.

## Manifest Ordering

```
00-secrets.yaml              -> DB credentials + encryption key
10-postgres-pvc.yaml         -> PostgreSQL data storage
11-n8n-pvc.yaml              -> n8n workflow data storage
20-postgres-deployment.yaml  -> PostgreSQL 17.8
30-n8n-deployment.yaml       -> n8n app (with wait-for-postgres init)
40-postgres-service.yaml     -> ClusterIP for PostgreSQL
41-n8n-service.yaml          -> NodePort 30080
```

## Health Checks

- PostgreSQL: `pg_isready -U n8n`
- n8n: HTTP GET `http://127.0.0.1:5678/healthz`
- PVC binding verification

## Access

```bash
# Web UI
http://<VM-IP>:30080
```

Owner account is created on first login via the web UI.

## Version Update Procedure

1. Check latest release at https://github.com/n8n-io/n8n/releases
2. Verify Docker Hub tag exists: `docker.io/n8nio/n8n:<new>`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make test-e2e APP=n8n`
