# apps/ghost/

Modern open-source publishing platform for blogs and newsletters. **Manifest** deployment method.

## Architecture

- **2-component stack**: Ghost app + MySQL 8.4
- **Deployment + Recreate**: Single-node K3s VM, all components as Deployments
- **NodePort 30080**: External access via HTTP (Ghost web UI)
- **Images**: `docker.io/library/ghost` (MIT), `docker.io/library/mysql:8.4` (GPLv2)

## Versions

Three versions supported: 6.19.1 (default), 5.130.6, 4.48.9.

## Parameters

All parameters use `PARAM_*` prefix at runtime. DB passwords are auto-generated in `hooks/pre-install.sh`.

## Manifest Ordering

```
00-secrets.yaml              -> DB credentials (root + user)
10-mysql-pvc.yaml            -> MySQL data storage
11-ghost-pvc.yaml            -> Ghost content storage
20-mysql-deployment.yaml     -> MySQL 8.4
30-ghost-deployment.yaml     -> Ghost app (with wait-for-mysql init)
40-mysql-service.yaml        -> ClusterIP for MySQL
41-ghost-service.yaml        -> NodePort 30080
```

## Health Checks

- MySQL: `healthcheck.sh --connect --innodb_initialized` (built-in)
- Ghost: HTTP GET `http://localhost:2368/ghost/api/v4/admin/site/`
- PVC binding verification

## Access

```bash
# Blog (public)
http://<VM-IP>:30080

# Admin panel
http://<VM-IP>:30080/ghost/
```

Admin account is created on first visit to `/ghost/` (setup wizard).

## Version Update Procedure

1. Check latest release at https://github.com/TryGhost/Ghost/releases
2. Verify Docker Hub tag exists: `docker.io/library/ghost:<new>`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make lint`
