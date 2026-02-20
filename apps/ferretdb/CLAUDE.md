# apps/ferretdb/

MongoDB-compatible database using PostgreSQL as the backend engine. **Manifest** deployment method.

## Architecture

- **2-component stack**: FerretDB app + PostgreSQL 17.8
- **Deployment + Recreate**: Single-node K3s VM, all components as Deployments
- **NodePort 30017**: External access via MongoDB wire protocol
- **Images**: `ghcr.io/ferretdb/ferretdb` (Apache 2.0), `postgres:17.8-alpine` (PostgreSQL License)

## Versions

Three versions supported: 2.7.0 (default), 2.5.0, 2.4.0.

## Parameters

All parameters use `PARAM_*` prefix at runtime. Database password is auto-generated in `hooks/pre-install.sh`.

## Manifest Ordering

```
00-secrets.yaml              -> PostgreSQL credentials
10-postgres-pvc.yaml         -> PostgreSQL data storage
20-postgres-deployment.yaml  -> PostgreSQL 17.8
30-ferretdb-deployment.yaml  -> FerretDB app (with wait-for-postgres init)
40-postgres-service.yaml     -> ClusterIP for PostgreSQL
41-ferretdb-service.yaml     -> NodePort 30017
```

## Health Checks

- PostgreSQL: `pg_isready -U ferretdb`
- FerretDB: `mongosh --port 27017 --eval "db.adminCommand('ping')"`
- PVC binding verification

## Networking / Firewall

The following ports must be opened at the firewall or load balancer level:

| Port | Protocol | Purpose | When |
|------|----------|---------|------|
| **30017** | TCP | MongoDB wire protocol access (NodePort) | Always |

## Access

```bash
mongosh mongodb://<VM-IP>:30017
```

FerretDB speaks MongoDB wire protocol, so all MongoDB clients and tools work directly.

## Version Update Procedure

1. Check latest release at https://github.com/FerretDB/FerretDB/releases
2. Verify ghcr.io tag exists: `ghcr.io/ferretdb/ferretdb:<new>`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make test-e2e APP=ferretdb`
