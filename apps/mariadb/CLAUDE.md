# apps/mariadb/

Standalone MariaDB database application using the **manifest** deployment method.

## Architecture

- **Single-tier**: MariaDB is the application itself (no separate app + DB)
- **Deployment + Recreate**: Single-node K3s VM, single replica
- **NodePort 30306**: External MySQL protocol access via `mysql -h <VM-IP> -P 30306`
- **Official image**: `docker.io/library/mariadb:<version>` (GPLv2)

## Versions

Three version lines supported: 11.4.10 (LTS, default), 10.11.16 (LTS), 10.6.25 (LTS).

## Parameters

All parameters use `PARAM_*` prefix at runtime. Credentials (root password, user password) are auto-generated in `hooks/pre-install.sh` if not provided.

## Manifest Ordering

```
00-secrets.yaml       -> Credentials (root password, user, user password, database)
10-pvc.yaml           -> Storage for /var/lib/mysql (local-path, RWO)
20-statefulset.yaml   -> MariaDB Deployment with probes
40-service.yaml       -> NodePort service on 30306
```

## Health Checks

- `mariadb-admin ping -u root -p<password>` via kubectl exec (connectivity)
- `SELECT 1` via kubectl exec (query execution)
- PVC binding verification

## Networking / Firewall

The following ports must be opened at the firewall or load balancer level:

| Port | Protocol | Purpose | When |
|------|----------|---------|------|
| **30306** | TCP | MySQL protocol access (NodePort) | Always |

## Version Update Procedure

1. Check latest patch at https://mariadb.org/download/
2. Verify Docker Hub tag exists: `docker.io/library/mariadb:<new>`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make test-e2e APP=mariadb`
