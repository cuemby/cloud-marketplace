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

| Parameter | Default | Description |
|-----------|---------|-------------|
| JOOMLA_ADMIN_PASSWORD | auto-generated | Admin password (12+ chars) |
| JOOMLA_DB_PASSWORD | auto-generated | MariaDB user password |
| JOOMLA_DB_ROOT_PASSWORD | auto-generated | MariaDB root password |

## Manifest Ordering

```
00-secrets.yaml              -> DB + admin credentials
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

Admin account (`admin`) is created automatically via Joomla auto-install env vars.
Password is auto-generated and stored in Secret `joomla-db-secret`.
Installation wizard is skipped automatically.

## Networking / Firewall

The following ports must be opened at the firewall or load balancer level:

| Port | Protocol | Purpose | When |
|------|----------|---------|------|
| **443** | HTTPS | Web UI via Traefik Gateway | SSL enabled |
| **80** | HTTP | Redirects to HTTPS (301) | SSL enabled |
| **30080** | TCP | Joomla web UI (NodePort) | Always |

## Version Update Procedure

1. Check latest release at https://www.joomla.org/announcements.html
2. Verify Docker Hub tag exists: `docker.io/library/joomla:<new>-apache`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make lint`
