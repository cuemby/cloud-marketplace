# apps/nextcloud/

Self-hosted file sharing, collaboration, and productivity platform. **Manifest** deployment method.

## Architecture

- **3-component stack**: Nextcloud app + MariaDB 11.4 + Valkey 8.1 (cache/sessions)
- **Deployment + Recreate**: Single-node K3s VM, all components as Deployments
- **NodePort 30080**: External access via HTTP (Nextcloud web UI)
- **Images**: `docker.io/library/nextcloud` (AGPLv3), `docker.io/library/mariadb:11.4` (GPLv2), `docker.io/valkey/valkey:8.1.5-alpine` (BSD 3-Clause)

## Versions

Three versions supported: 33.0.0 (default), 32.0.3, 31.0.12.

## Parameters

All parameters use `PARAM_*` prefix at runtime. Passwords are auto-generated in `hooks/pre-install.sh`.

## Manifest Ordering

```
00-secrets.yaml              -> Admin + DB + Valkey credentials
10-mariadb-pvc.yaml          -> MariaDB data storage
11-nextcloud-pvc.yaml        -> Nextcloud data storage
20-mariadb-deployment.yaml   -> MariaDB 11.4
21-valkey-deployment.yaml    -> Valkey 8.1 (cache/sessions)
30-nextcloud-deployment.yaml -> Nextcloud app (with wait-for-mariadb init)
40-mariadb-service.yaml      -> ClusterIP for MariaDB
41-valkey-service.yaml       -> ClusterIP for Valkey
42-nextcloud-service.yaml    -> NodePort 30080
```

## Health Checks

- MariaDB: `healthcheck.sh --connect --innodb_initialized` (built-in)
- Nextcloud: `curl http://localhost/status.php` (returns JSON with `"installed":true`)
- PVC binding verification

## Access

```bash
# Web UI
http://<VM-IP>:30080

# Status endpoint
http://<VM-IP>:30080/status.php
```

Admin credentials are configured during deployment via env vars (no setup wizard).

## Version Update Procedure

1. Check latest release at https://github.com/nextcloud/server/releases
2. Verify Docker Hub tag exists: `docker.io/library/nextcloud:<new>-apache`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make lint`
