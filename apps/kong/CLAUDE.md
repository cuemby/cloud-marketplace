# apps/kong/

Cloud-native API gateway for managing, securing, and observing APIs and microservices. **Manifest** deployment method.

## Architecture

- **2-component stack**: Kong Gateway + PostgreSQL 17.8
- **Deployment + Recreate**: Single-node K3s VM, all components as Deployments
- **Migrations Job**: `kong migrations bootstrap` runs as a Kubernetes Job before Kong starts
- **NodePort 30800**: Proxy (API traffic), **NodePort 30801**: Admin API
- **Images**: `docker.io/library/kong` (Apache 2.0), `postgres:17.8-alpine` (PostgreSQL License)

## Versions

Three versions supported: 3.9.1 (default), 3.8.1, 3.7.1.

## Parameters

All parameters use `PARAM_*` prefix at runtime. Database password is auto-generated in `hooks/pre-install.sh`.

## Manifest Ordering

```
00-secrets.yaml              -> PostgreSQL credentials
10-postgres-pvc.yaml         -> PostgreSQL data storage
20-postgres-statefulset.yaml -> PostgreSQL 17.8
25-kong-migrations-job.yaml  -> Kong migrations bootstrap (runs once)
30-kong-deployment.yaml      -> Kong Gateway (with wait-for-postgres init)
40-postgres-service.yaml     -> ClusterIP for PostgreSQL
41-kong-proxy-service.yaml   -> NodePort 30800 (Proxy)
42-kong-admin-service.yaml   -> NodePort 30801 (Admin API)
```

## Health Checks

- PostgreSQL: `pg_isready -U kong`
- Kong: `curl http://localhost:8001/status` (Admin API)
- Migrations: Job completion check
- PVC binding verification

## Access

```bash
# Proxy (route API traffic through Kong)
curl http://<VM-IP>:30800

# Admin API (manage routes, services, plugins)
curl http://<VM-IP>:30801/status
curl http://<VM-IP>:30801/services
curl http://<VM-IP>:30801/routes
```

## Version Update Procedure

1. Check latest release at https://github.com/Kong/kong/releases
2. Verify Docker Hub tag exists: `docker.io/library/kong:<new>`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make test-e2e APP=kong`
