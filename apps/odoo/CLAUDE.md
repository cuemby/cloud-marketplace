# Odoo Community

## Architecture

- **Type**: 2-component stack (Odoo + PostgreSQL 17.8)
- **Deploy method**: Manifest (raw K8s YAML + envsubst)
- **Runtime**: Single-node K3s VM, Deployments with Recreate strategy

## Components

| Component | Image | Role |
|---|---|---|
| Odoo | `docker.io/library/odoo` | ERP/business application server |
| PostgreSQL | `postgres:17.8-alpine` | Relational database backend |

## Parameters

| Name | Effect |
|---|---|
| `ODOO_DB_PASSWORD` | PostgreSQL password for Odoo (auto-generated) |
| `ODOO_ADMIN_PASSWORD` | Admin master password for database management (auto-generated) |
| `ODOO_DB_DATA_SIZE` | PostgreSQL PVC size (default: 10Gi) |
| `ODOO_DATA_SIZE` | Odoo filestore/addons PVC size (default: 10Gi) |

## Health Checks

- **PostgreSQL**: `pg_isready -U odoo` (exec probe)
- **Odoo**: HTTP GET `http://127.0.0.1:8069/web/database/selector` (startup/liveness/readiness)
- **PVC binding**: All PVCs must be in `Bound` phase

## Networking / Firewall

The following ports must be opened at the firewall or load balancer level:

| Port | Protocol | Purpose | When |
|------|----------|---------|------|
| **443** | HTTPS | Web UI via Traefik Gateway | SSL enabled |
| **80** | HTTP | Redirects to HTTPS (301) | SSL enabled |
| **30069** | TCP | Odoo web UI (NodePort) | Always |

## Access

- **Web UI**: `http://<VM-IP>:30069`
- **Default credentials**: Set admin master password and create first database on initial login

## Version Update

1. Check available tags at https://hub.docker.com/_/odoo/tags
2. Update `versions` in `app.yaml` (keep 3 lines)
3. Run `make validate && make catalog`
