# OpenClaw — App-Level CLAUDE.md

## Architecture

- **Type**: Single-tier (AI assistant gateway)
- **Components**: OpenClaw (personal AI assistant with messaging integrations)
- **Deploy method**: Manifest (raw K8s YAML + envsubst)
- **Storage**: PVC via `local-path` StorageClass (SQLite + memory + transcripts)

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

## Health Check

1. Pod readiness condition (`Ready=True`) — gateway TCP probe on port 18789
2. PVC bound status verification

## Access

| Endpoint | Port | Protocol |
|----------|------|----------|
| Gateway | 30789 (NodePort) | WebSocket |

## Version Update

1. Check available tags at GHCR: `ghcr.io/openclaw/openclaw`
2. Update `versions` array in `app.yaml`
3. Run `make validate && make lint && make catalog`
4. Test with `make test-integration` if available

## Notes

- OpenClaw uses SQLite for storage (no external database required).
- Data is stored in `/home/node/.openclaw` inside the container.
- The gateway runs on port 18789 and communicates via WebSocket.
- Single-instance only; cannot scale horizontally.
- Runs as non-root user (UID 1000).
- License: MIT (open-source).
