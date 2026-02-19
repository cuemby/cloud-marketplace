# apps/valkey/

Standalone Valkey in-memory data store using the **manifest** deployment method.

## Architecture

- **Single-tier**: Valkey is the application itself (no separate app + DB)
- **Deployment + Recreate**: Single-node K3s VM, single replica
- **NodePort 30379**: External Valkey protocol access via `valkey-cli -h <VM-IP> -p 30379`
- **Official image**: `docker.io/valkey/valkey:<version>-alpine` (BSD 3-Clause)
- **Drop-in Redis replacement**: Linux Foundation project, identical API and CLI

## Versions

Three version lines supported: 8.1.5 (stable, default), 9.0.2 (latest), 8.0.3 (prior stable).
All use Alpine variants for smaller image size.

## Parameters

All parameters use `PARAM_*` prefix at runtime. Password is auto-generated in `hooks/pre-install.sh` if not provided.

- `VALKEY_PASSWORD` — authentication password
- `VALKEY_DATA_SIZE` — PVC size (default: 5Gi)
- `VALKEY_MAXMEMORY` — max memory for data (default: 1gb)
- `VALKEY_MAXMEMORY_POLICY` — eviction policy (default: allkeys-lru)

## Manifest Ordering

```
00-secrets.yaml       -> Password credential
05-configmap.yaml     -> valkey.conf (maxmemory, AOF persistence, RDB snapshots)
10-pvc.yaml           -> Storage for /data (local-path, RWO)
20-statefulset.yaml   -> Valkey Deployment with --requirepass and config mount
40-service.yaml       -> NodePort service on 30379
```

## Health Checks

- `valkey-cli -a <password> ping` via kubectl exec (connectivity)
- `SET healthcheck_test "ok"` via kubectl exec (write operation)
- PVC binding verification

## Version Update Procedure

1. Check latest releases at https://github.com/valkey-io/valkey/releases
2. Verify Docker Hub tag exists: `docker.io/valkey/valkey:<new>-alpine`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make test-e2e APP=valkey`
