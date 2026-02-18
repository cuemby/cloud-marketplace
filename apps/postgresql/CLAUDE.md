# apps/postgresql/

Standalone PostgreSQL database application using the **manifest** deployment method.

## Architecture

- **Single-tier**: PostgreSQL is the application itself (no separate app + DB like WordPress)
- **Deployment + Recreate**: Single-node K3s VM, no StatefulSet needed
- **NodePort 30432**: External psql access via `psql -h <VM-IP> -p 30432`
- **Official image**: `docker.io/library/postgres:<version>-alpine` (PostgreSQL License)

## Versions

Three latest major versions supported: 17.8, 16.12, 15.16 (Alpine variants).

## Parameters

All parameters use `PARAM_*` prefix at runtime. Credentials are auto-generated in `hooks/pre-install.sh` if not provided. Tuning params (max_connections, shared_buffers, work_mem) are passed via PostgreSQL `-c` command-line flags.

## Manifest Ordering

```
00-secrets.yaml              → Credentials (POSTGRES_PASSWORD, USER, DB)
05-configmap.yaml            → Tuning parameters (stored for reference)
10-postgresql-pvc.yaml       → Storage for PGDATA (local-path, RWO)
20-postgresql-deployment.yaml → PostgreSQL Deployment with probes
40-postgresql-service.yaml   → NodePort service on 30432
```

## Health Checks

- `pg_isready -U <user>` via kubectl exec (connectivity)
- `SELECT 1` via kubectl exec (query execution)
- PVC binding verification

## Version Update Procedure

1. Check latest patch at https://www.postgresql.org/support/versioning/
2. Verify Docker Hub tag exists: `docker.io/library/postgres:<new>-alpine`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make test-e2e APP=postgresql`
