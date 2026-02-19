# apps/owncloud/

Self-hosted file sync and share platform with enterprise-grade security. **Manifest** deployment method.

## Architecture

- **3-component stack**: ownCloud app + MariaDB 11.4 + Valkey 8.1 (cache)
- **Deployment + Recreate**: Single-node K3s VM, all components as Deployments
- **NodePort 30080**: External access via HTTP (ownCloud web UI on port 8080)
- **Images**: `docker.io/owncloud/server` (AGPLv3), `docker.io/library/mariadb:11.4` (GPLv2), `docker.io/valkey/valkey:8.1.5-alpine` (BSD 3-Clause)

## Versions

Three versions supported: 10.16.0 (default), 10.15.3, 10.14.0.

## Parameters

All parameters use `PARAM_*` prefix at runtime. Passwords are auto-generated in `hooks/pre-install.sh`.

## Manifest Ordering

```
00-secrets.yaml              -> Admin + DB + Valkey credentials
10-mariadb-pvc.yaml          -> MariaDB data storage
11-owncloud-pvc.yaml         -> ownCloud data storage
20-mariadb-deployment.yaml   -> MariaDB 11.4
21-valkey-deployment.yaml    -> Valkey 8.1 (cache)
30-owncloud-deployment.yaml  -> ownCloud app (with wait-for-mariadb + wait-for-valkey init)
40-mariadb-service.yaml      -> ClusterIP for MariaDB
41-valkey-service.yaml       -> ClusterIP for Valkey
42-owncloud-service.yaml     -> NodePort 30080
```

## Health Checks

- MariaDB: `healthcheck.sh --connect --innodb_initialized` (built-in)
- ownCloud: `curl http://localhost:8080/status.php` (returns JSON with version info)
- PVC binding verification

## Access

```bash
# Web UI
http://<VM-IP>:30080

# Status endpoint
http://<VM-IP>:30080/status.php
```

Admin credentials are configured during deployment via env vars.

## Version Update Procedure

1. Check latest release at https://github.com/owncloud-docker/server/releases
2. Verify Docker Hub tag exists: `docker.io/owncloud/server:<new>`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make lint`
