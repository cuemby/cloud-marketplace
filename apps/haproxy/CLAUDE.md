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

## Networking / Firewall

The following ports must be opened at the firewall or load balancer level:

| Port | Protocol | Purpose | When |
|------|----------|---------|------|
| **443** | HTTPS | HTTP proxy via Traefik Gateway | SSL enabled |
| **80** | HTTP | Redirects to HTTPS (301) | SSL enabled |
| **30080** | TCP | HTTP frontend (NodePort) | Always |
| **30936** | TCP | Stats dashboard (NodePort) | Always |

## Access

| Endpoint | Port | Protocol |
|----------|------|----------|
| HTTP Frontend | 30080 (NodePort) | HTTP |
| Stats Dashboard | 30936 (NodePort) | HTTP |
| HTTPS Frontend | 443 (Gateway) | HTTPS |
| HTTPS Stats | 443 /stats (Gateway) | HTTPS |

## Ports

- **8080**: HTTP frontend (default backend returns 503 — configure backends as needed)
- **8936**: Stats and health monitoring interface

## Version Update

1. Check available tags at Docker Hub: `library/haproxy`
2. Update `versions` array in `app.yaml` (use `-alpine` variants)
3. Run `make validate && make lint && make catalog`
4. Test with `make test-integration` if available

## Manifest Ordering

```
00-secrets.yaml              -> Stats credentials (user/password)
05-configmap.yaml            -> HAProxy config (frontends, backends, stats)
20-deployment.yaml           -> HAProxy Deployment with probes
40-service.yaml              -> NodePort 30080 (HTTP frontend)
41-service-stats.yaml        -> NodePort 30936 (Stats dashboard)
42-service-http.yaml         -> ClusterIP for HTTPS Gateway
43-service-stats-internal.yaml -> ClusterIP for /stats via HTTPS Gateway
44-httproute-stats.yaml      -> HTTPRoute for /stats and /healthz via HTTPS
50-demo-backends.yaml        -> 3 nginx demo backends (round-robin demo)
```

## Demo Backends

Three color-coded nginx servers (blue/green/red) are deployed as demo backends to
showcase HAProxy round-robin load balancing. To remove them:

```bash
kubectl -n app-haproxy delete deploy,svc,configmap -l app.kubernetes.io/component=demo
# Then edit ConfigMap 'haproxy-config' with your real backend servers.
```

## Notes

- Stats dashboard accessible via HTTPS at `/stats` (routed through Gateway).
- Demo backends deployed by default for load-balancing demonstration.
- Users should replace demo backends with real servers after evaluation.
- License: GPLv2 (fully open-source).
