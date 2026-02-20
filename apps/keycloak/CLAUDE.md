# apps/keycloak/

Identity and access management using the **manifest** deployment method.

## Architecture

- **2-component stack**: Keycloak app + PostgreSQL 15
- **Deployment + Recreate**: Single-node K3s VM, all components as Deployments
- **NodePort 30808**: External access to Keycloak web UI
- **Dev mode**: Uses `start-dev` command (HTTP only, no TLS required)
- **Images**: `quay.io/keycloak/keycloak` (Apache 2.0), `postgres:15-alpine`

## Versions

Three versions supported: 26.5.3, 25.0.6, 24.0.5.

## Parameters

All parameters use `PARAM_*` prefix at runtime. Credentials (admin password, DB password) are auto-generated in `hooks/pre-install.sh`.

## Admin Account

Keycloak supports automated admin creation via `KC_BOOTSTRAP_ADMIN_USERNAME` and `KC_BOOTSTRAP_ADMIN_PASSWORD` environment variables. The admin account is created at first boot.

## Manifest Ordering

```
00-secrets.yaml              -> Dual secrets (DB + app credentials)
05-configmap.yaml            -> KC_DB, KC_HEALTH_ENABLED, etc.
10-postgres-pvc.yaml         -> PostgreSQL data storage
11-keycloak-pvc.yaml         -> Keycloak data storage
20-postgres-deployment.yaml  -> PostgreSQL 15
30-keycloak-deployment.yaml  -> Keycloak app (with wait-for-postgres init)
40-postgres-service.yaml     -> ClusterIP for PostgreSQL
41-keycloak-service.yaml     -> NodePort 30808 for UI
```

## Networking / Firewall

The following ports must be opened at the firewall or load balancer level:

| Port | Protocol | Purpose | When |
|------|----------|---------|------|
| **443** | HTTPS | Web UI via Traefik Gateway | SSL enabled |
| **80** | HTTP | Redirects to HTTPS (301) | SSL enabled |
| **30808** | TCP | Keycloak web UI (NodePort) | Always |

## Health Checks

- PostgreSQL: `pg_isready -U keycloak`
- Keycloak: `GET /health/ready` on port 9000 (management port)
- PVC binding verification

## Version Update Procedure

1. Check latest release at https://github.com/keycloak/keycloak/releases
2. Verify Quay.io tag exists: `quay.io/keycloak/keycloak:<new>`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make test-e2e APP=keycloak`
