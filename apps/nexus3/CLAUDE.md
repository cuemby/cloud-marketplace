# Nexus3 — App-Level CLAUDE.md

## Architecture

- **Type**: Single-tier (repository manager)
- **Components**: Sonatype Nexus Repository OSS
- **Deploy method**: Manifest (raw K8s YAML + envsubst)
- **Storage**: PVC via `local-path` StorageClass

## Components

| Component | Image | Role |
|-----------|-------|------|
| Nexus3 | `docker.io/sonatype/nexus3` | Universal repository manager (Maven, npm, Docker, etc.) |

## Parameters

| Parameter | Default | Effect |
|-----------|---------|--------|
| `NEXUS_DATA_SIZE` | `50Gi` | PVC size for repository data |

## Health Check

1. HTTP GET `http://localhost:8081/service/rest/v1/status` — Nexus REST API status
2. PVC bound status verification

## Networking / Firewall

The following ports must be opened at the firewall or load balancer level:

| Port | Protocol | Purpose | When |
|------|----------|---------|------|
| **443** | HTTPS | Web UI via Traefik Gateway | SSL enabled |
| **80** | HTTP | Redirects to HTTPS (301) | SSL enabled |
| **30081** | TCP | Nexus web UI / API (NodePort) | Always |

## Access

| Endpoint | Port | Protocol |
|----------|------|----------|
| Web UI / API | 30081 (NodePort) | HTTP |

## Version Update

1. Check available tags at Docker Hub: `sonatype/nexus3`
2. Update `versions` array in `app.yaml`
3. Run `make validate && make lint && make catalog`
4. Test with `make test-integration` if available

## Notes

- No credentials are configured externally; Nexus auto-generates an admin password at `/nexus-data/admin.password` on first startup.
- Retrieve initial admin password: `kubectl exec -n <namespace> <pod> -- cat /nexus-data/admin.password`
- The Nexus3 image runs as UID 200 (`nexus` user); `securityContext` sets `runAsUser: 200` and `fsGroup: 200`.
- Nexus3 requires significant memory (2-3 GB heap); memory limit set to 3072Mi by default.
- Startup can take 2-3 minutes; startup probe has `failureThreshold: 30` with 10s periods.
- License: EPL 1.0 (Eclipse Public License, OSI-approved).
