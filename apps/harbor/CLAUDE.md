# Harbor — Per-App CLAUDE.md

## Purpose
Cloud-native container registry with vulnerability scanning, content signing, and role-based access control.

## Architecture
- **Components**: 7 — Harbor Core, Portal (Nginx UI), Registry+Registryctl, Harbor DB (PostgreSQL), JobService, Valkey (cache/sessions), Trivy (vulnerability scanner)
- **Deploy method**: `manifest` (raw YAML, envsubst interpolation)
- **Strategy**: `Recreate` (single-node, no rolling updates)
- **Storage**: 3 PVCs — DB data, registry blob storage, jobservice logs
- **Networking**: ClusterIP for all internal services, NodePort 30443 for Portal

## Component Startup Order
1. Harbor DB (PostgreSQL) + Valkey — no dependencies
2. Registry — waits for Valkey
3. Core — waits for DB + Registry
4. JobService — waits for Core
5. Portal — no dependencies (Nginx serves static UI)
6. Trivy — waits for Valkey

## Secrets
- `harbor-core-secret` — admin password, secret key, core secret, CSRF key
- `harbor-db-secret` — PostgreSQL credentials (user: harbor, db: registry)
- `harbor-valkey-secret` — Valkey password
- `harbor-registry-secret` — registry HTTP secret
- `harbor-jobservice-secret` — jobservice secret

## Parameters
| Parameter | Default | Description |
|-----------|---------|-------------|
| HARBOR_ADMIN_PASSWORD | auto-generated | Admin password |
| HARBOR_DB_PASSWORD | auto-generated | PostgreSQL password |
| HARBOR_SECRET_KEY | auto-generated (16 chars) | Encryption key for Harbor secrets |
| HARBOR_VALKEY_PASSWORD | auto-generated | Valkey cache password |
| HARBOR_REGISTRY_DATA_SIZE | 50Gi | Registry blob storage |
| HARBOR_DB_DATA_SIZE | 10Gi | PostgreSQL data |

## Health Checks
- **DB**: `pg_isready -U harbor -d registry`
- **Core API**: `GET http://localhost:8080/api/v2.0/ping`
- **Registry**: `GET http://localhost:5000/`
- **Portal**: `GET http://localhost:8080/`
- **JobService**: `GET http://localhost:8080/api/v1/stats`
- **Trivy**: `GET http://localhost:8080/probe/healthy`
- **PVCs**: All must be in Bound state

## Access
```bash
# Web UI (via Portal NodePort)
curl http://<VM-IP>:30443

# API health check
curl http://<VM-IP>:30443/api/v2.0/health

# Docker login
docker login <VM-IP>:30443 -u admin -p <password>
```

## Networking / Firewall

The following ports must be opened at the firewall or load balancer level:

| Port | Protocol | Purpose | When |
|------|----------|---------|------|
| **443** | HTTPS | Portal via Traefik Gateway | SSL enabled |
| **80** | HTTP | Redirects to HTTPS (301) | SSL enabled |
| **30443** | TCP | Portal (NodePort) | Always |

## Version Updates
1. Check [Harbor Releases](https://github.com/goharbor/harbor/releases)
2. All Harbor images share the same tag (e.g., `v2.14.2`)
3. Valkey image is fixed at 8.1.5-alpine (independent of Harbor version)
4. Update `versions[]` in app.yaml
5. Run E2E tests with new version
