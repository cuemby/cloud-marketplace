# apps/nats-jetstream/

High-performance cloud-native messaging system with built-in JetStream persistence. **Manifest** deployment method.

## Architecture

- **Single-tier**: NATS server with JetStream enabled
- **Deployment + Recreate**: Single-node K3s VM, single replica
- **NodePort 30422**: NATS client connections
- **NodePort 30822**: HTTP monitoring endpoint
- **Official image**: `docker.io/library/nats:<version>` (Apache 2.0)

## Versions

Single version: 2.12.4 (default).

## Parameters

All parameters use `PARAM_*` prefix at runtime. Auth token is auto-generated in `hooks/pre-install.sh` if not provided.

## Manifest Ordering

Check `apps/nats-jetstream/manifests/` for the ordered manifest files.

## Health Checks

- NATS health endpoint via K8s API proxy (`/healthz`)
- PVC binding verification

## Networking / Firewall

The following ports must be opened at the firewall or load balancer level:

| Port | Protocol | Purpose | When |
|------|----------|---------|------|
| **30422** | TCP | NATS client connections (NodePort) | Always |
| **30822** | TCP | HTTP monitoring endpoint (NodePort) | Always |

## Version Update Procedure

1. Check latest release at https://github.com/nats-io/nats-server/releases
2. Verify Docker Hub tag exists: `docker.io/library/nats:<new>`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make test-e2e APP=nats-jetstream`
