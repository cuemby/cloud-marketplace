# apps/joomla/

Flexible open-source CMS for websites and online applications. **Manifest** deployment method.

## Architecture

- **2-component stack**: Joomla app + MariaDB 11.4
- **Deployment + Recreate**: Single-node K3s VM, all components as Deployments
- **NodePort 30080**: External access via HTTP (Joomla web UI)
- **Images**: `docker.io/library/joomla` (GPLv2), `docker.io/library/mariadb:11.4` (GPLv2)

## Versions

Three versions supported: 6.0.3 (default), 5.4.3, 5.3.2.

## Parameters

All parameters use `PARAM_*` prefix at runtime. DB passwords are auto-generated in `hooks/pre-install.sh`.

## Manifest Ordering

```
00-secrets.yaml              -> DB credentials (root + user)
10-mariadb-pvc.yaml          -> MariaDB data storage
11-joomla-pvc.yaml           -> Joomla data storage
20-mariadb-deployment.yaml   -> MariaDB 11.4
30-joomla-deployment.yaml    -> Joomla app (with wait-for-mariadb init)
40-mariadb-service.yaml      -> ClusterIP for MariaDB
41-joomla-service.yaml       -> NodePort 30080
```

## Health Checks

- MariaDB: `healthcheck.sh --connect --innodb_initialized` (built-in)
- Joomla: HTTP GET `http://localhost:80/` (check for 200/301/302 status)
- PVC binding verification

## Access

```bash
# Joomla site
http://<VM-IP>:30080

# Admin panel
http://<VM-IP>:30080/administrator/
```

Admin account is created on first visit (installation wizard).

## Version Update Procedure

1. Check latest release at https://www.joomla.org/announcements.html
2. Verify Docker Hub tag exists: `docker.io/library/joomla:<new>-apache`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make lint`
