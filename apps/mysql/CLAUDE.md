# apps/mysql/

Standalone MySQL database application using the **manifest** deployment method.

## Architecture

- **Single-tier**: MySQL is the application itself (no separate app + DB)
- **Deployment + Recreate**: Single-node K3s VM, single replica
- **NodePort 30306**: External MySQL protocol access via `mysql -h <VM-IP> -P 30306`
- **Official image**: `docker.io/library/mysql:<version>` (GPLv2)

## Versions

Three version lines supported: 8.4.8 (LTS, default), 9.6.0 (Innovation), 8.0.45 (LTS).

## Parameters

All parameters use `PARAM_*` prefix at runtime. Credentials (root password, user password) are auto-generated in `hooks/pre-install.sh` if not provided.

## Manifest Ordering

```
00-secrets.yaml       -> Credentials (root password, user, user password, database)
10-pvc.yaml           -> Storage for /var/lib/mysql (local-path, RWO)
20-statefulset.yaml   -> MySQL Deployment with probes
40-service.yaml       -> NodePort service on 30306
```

## Health Checks

- `mysqladmin ping -u root -p<password>` via kubectl exec (connectivity)
- `SELECT 1` via kubectl exec (query execution)
- PVC binding verification

## Networking / Firewall

The following ports must be opened at the firewall or load balancer level:

| Port | Protocol | Purpose | When |
|------|----------|---------|------|
| **30306** | TCP | MySQL protocol access (NodePort) | Always |

## Version Update Procedure

1. Check latest patch at https://dev.mysql.com/downloads/mysql/
2. Verify Docker Hub tag exists: `docker.io/library/mysql:<new>`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make test-e2e APP=mysql`
