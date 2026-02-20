# OpenClaw — App-Level CLAUDE.md

## Architecture

- **Type**: Single-tier (AI assistant gateway)
- **Components**: OpenClaw (personal AI assistant with messaging integrations)
- **Deploy method**: Manifest (raw K8s YAML + envsubst)
- **Storage**: PVC via `local-path` StorageClass (SQLite + memory + transcripts)
- **SSL**: cert-manager + Traefik Gateway API, auto-detected sslip.io hostname

## Components

| Component | Image | Role |
|-----------|-------|------|
| OpenClaw | `ghcr.io/openclaw/openclaw` | Personal AI assistant gateway |

## Parameters

| Parameter | Default | Effect |
|-----------|---------|--------|
| `OPENCLAW_API_KEY` | (required) | LLM provider API key (Anthropic, OpenAI, etc.) |
| `OPENCLAW_LLM_PROVIDER` | `anthropic` | Which LLM provider to use |
| `OPENCLAW_DATA_SIZE` | `10Gi` | PVC size for SQLite, memory, and transcripts |
| `OPENCLAW_SSL_ENABLED` | `true` | Enable HTTPS via Let's Encrypt + sslip.io |
| `OPENCLAW_HOSTNAME` | (auto-detected) | Custom hostname; defaults to `<IP>.sslip.io` |

## Networking / Firewall

The following ports must be opened at the firewall or load balancer level:

| Port | Protocol | Purpose | When |
|------|----------|---------|------|
| **443** | HTTPS | Web UI and WebSocket via Traefik Gateway | SSL enabled |
| **80** | HTTP | Redirects to HTTPS (301) | SSL enabled |
| **30789** | TCP | Direct WebSocket gateway access (NodePort) | Always |

When SSL is enabled, Traefik terminates TLS on ports 80/443 and routes to the internal `openclaw-http` ClusterIP service (port 80 → 18789).

## Health Check

1. Pod readiness condition (`Ready=True`) — gateway TCP probe on port 18789
2. PVC bound status verification

## Access

```bash
# Web UI (HTTPS, when SSL enabled)
https://<IP>.sslip.io

# Direct WebSocket access (always available)
ws://<VM-IP>:30789
```

## Version Update

1. Check available tags at GHCR: `ghcr.io/openclaw/openclaw`
2. Update `versions` array in `app.yaml`
3. Run `make validate && make lint && make catalog`
4. Test with `make test-integration` if available

## Notes

- OpenClaw uses SQLite for storage (no external database required).
- Data is stored in `/home/node/.openclaw` inside the container.
- The gateway runs on port 18789 and serves both the Control UI and WebSocket API.
- Single-instance only; cannot scale horizontally.
- Runs as non-root user (UID 1000).
- License: MIT (open-source).
