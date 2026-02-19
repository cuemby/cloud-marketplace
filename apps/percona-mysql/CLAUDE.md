# apps/percona-mysql/

Standalone Percona Server for MySQL database application using the **manifest** deployment method.

## Architecture

- **Single-tier**: Percona MySQL is the application itself (no separate app + DB)
- **Deployment + Recreate**: Single-node K3s VM, single replica
- **NodePort 30306**: External MySQL protocol access via `mysql -h <VM-IP> -P 30306`
- **Image**: `docker.io/percona/percona-server:<version>` (GPLv2)

## Versions

Three version lines supported: 8.4.7 (LTS, default), 8.0.45 (LTS), 8.0.44 (LTS).

## Parameters

All parameters use `PARAM_*` prefix at runtime. Credentials (root password, user password) are auto-generated in `hooks/pre-install.sh` if not provided.

## Manifest Ordering

```
00-secrets.yaml       -> Credentials (root password, user, user password, database)
10-pvc.yaml           -> Storage for /var/lib/mysql (local-path, RWO)
20-statefulset.yaml   -> Percona MySQL Deployment with probes
40-service.yaml       -> NodePort service on 30306
```

## Health Checks

- `mysqladmin ping -u root -p<password>` via kubectl exec (connectivity)
- `SELECT 1` via kubectl exec (query execution)
- PVC binding verification

## Percona vs MySQL

Percona Server is a drop-in replacement for MySQL with additional features:
- XtraDB storage engine (enhanced InnoDB)
- Thread pool for better concurrency
- Audit logging plugin
- PAM authentication
- TokuDB engine (legacy)

Uses the same MySQL CLI tools (`mysqladmin`, `mysql`) and is wire-compatible.

## Version Update Procedure

1. Check latest release at https://www.percona.com/software/mysql-database
2. Verify Docker Hub tag exists: `docker.io/percona/percona-server:<new>`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make test-e2e APP=percona-mysql`
