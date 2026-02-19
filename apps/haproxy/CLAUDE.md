# HAProxy — App-Level CLAUDE.md

## Architecture

- **Type**: Single-tier (load balancer / proxy server)
- **Components**: HAProxy (TCP/HTTP load balancer with stats UI)
- **Deploy method**: Manifest (raw K8s YAML + envsubst)
- **Storage**: None (stateless; configuration via ConfigMap)

## Components

| Component | Image | Role |
|-----------|-------|------|
| HAProxy | `docker.io/library/haproxy` (Alpine) | TCP/HTTP load balancer and proxy with stats dashboard |

## Parameters

| Parameter | Default | Effect |
|-----------|---------|--------|
| `HAPROXY_STATS_PASSWORD` | (auto-generated) | Password for stats web interface |
| `HAPROXY_STATS_USER` | `admin` | Username for stats web interface |

## Health Check

1. HTTP GET `http://localhost:8936/healthz` — stats page responding (via `monitor-uri`)
2. Stats interface accessible at `http://localhost:8936/stats`
3. Pod running status verification

## Access

| Endpoint | Port | Protocol |
|----------|------|----------|
| HTTP Frontend | 30080 (NodePort) | HTTP |
| Stats Dashboard | 30936 (NodePort) | HTTP |

## Ports

- **8080**: HTTP frontend (default backend returns 503 — configure backends as needed)
- **8936**: Stats and health monitoring interface

## Version Update

1. Check available tags at Docker Hub: `library/haproxy`
2. Update `versions` array in `app.yaml` (use `-alpine` variants)
3. Run `make validate && make lint && make catalog`
4. Test with `make test-integration` if available

## Notes

- HAProxy ships with a default configuration that includes stats and a placeholder HTTP frontend.
- Users should customize the ConfigMap (`05-configmap.yaml`) with their backend servers after deployment.
- The default frontend returns 503 until backends are configured.
- License: GPLv2 (fully open-source).
