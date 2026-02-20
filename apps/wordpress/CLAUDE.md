# apps/wordpress/

Open-source content management system for building websites, blogs, and applications. **Manifest** deployment method.

## Architecture

- **2-component stack**: WordPress app + MariaDB 11.4
- **Deployment + Recreate**: Single-node K3s VM, all components as Deployments
- **NodePort 30080**: External access via HTTP (WordPress on port 80)
- **Images**: `docker.io/library/wordpress` (GPLv2), `docker.io/library/mariadb:11.4` (GPLv2)

## Versions

Single version supported: 6.9.1 (default), uses `6.9.1-apache` image tag.

## Parameters

All parameters use `PARAM_*` prefix at runtime. MariaDB passwords and WordPress admin password are auto-generated in `hooks/pre-install.sh`.

## Manifest Ordering

```
00-secrets.yaml              -> DB credentials (root + user) + WordPress DB connection
05-configmap.yaml            -> WordPress config extras (memory limits, disable file edit)
10-mariadb-pvc.yaml          -> MariaDB data storage
11-wordpress-pvc.yaml        -> WordPress files storage (/var/www/html)
20-mariadb-deployment.yaml   -> MariaDB 11.4
30-wordpress-deployment.yaml -> WordPress app (with wait-for-mariadb init)
40-mariadb-service.yaml      -> ClusterIP for MariaDB
41-wordpress-service.yaml    -> NodePort 30080
42-wordpress-http-service.yaml -> ClusterIP port 80 -> 80 (for SSL/Gateway)
```

## Health Checks

- MariaDB: `healthcheck.sh --connect --innodb_initialized` (built-in)
- WordPress: HTTP GET `http://localhost/wp-login.php` (startup uses `/wp-admin/install.php`)
- PVC binding verification

## Networking / Firewall

The following ports must be opened at the firewall or load balancer level:

| Port | Protocol | Purpose | When |
|------|----------|---------|------|
| **443** | HTTPS | Web UI via Traefik Gateway | SSL enabled |
| **80** | HTTP | Redirects to HTTPS (301) | SSL enabled |
| **30080** | TCP | WordPress web UI (NodePort) | Always |

## Access

```bash
# Site (public)
http://<VM-IP>:30080

# Admin panel
http://<VM-IP>:30080/wp-admin

# Default admin: configured via PARAM_WORDPRESS_ADMIN_USER (default "admin")
```

WordPress installation is completed automatically via POST to `/wp-admin/install.php` in `hooks/post-install.sh`.

## Version Update Procedure

1. Check latest release at https://wordpress.org/download/releases/
2. Verify Docker Hub tag exists: `docker.io/library/wordpress:<new>-apache`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make test-e2e APP=wordpress`
