# SeaweedFS — App-Level CLAUDE.md

## Architecture

- **Type**: Single-tier (all-in-one server)
- **Components**: SeaweedFS server (master + volume + filer + S3 gateway in one process)
- **Deploy method**: Manifest (raw K8s YAML + envsubst)
- **Storage**: PVC via `local-path` StorageClass

## Components

| Component | Image | Role |
|-----------|-------|------|
| SeaweedFS | `docker.io/chrislusf/seaweedfs` | Master, volume server, filer, and S3 API gateway |

The `weed server -s3` command runs all components in a single process, suitable for single-node deployments.

## Parameters

| Parameter | Default | Effect |
|-----------|---------|--------|
| `SEAWEEDFS_DATA_SIZE` | `50Gi` | PVC size for data storage |
| `SEAWEEDFS_VOLUME_SIZE_LIMIT` | `1000` | Max size of each volume file in MB |

## Health Check

1. HTTP GET `http://localhost:9333/cluster/status` — master health (checks `IsLeader` in response)
2. HTTP GET `http://localhost:8333/` — S3 API endpoint responding
3. PVC bound status verification

## Access

| Endpoint | Port | Protocol |
|----------|------|----------|
| S3 API | 30833 (NodePort) | HTTP |
| Filer | 30888 (NodePort) | HTTP |
| Master | 30933 (NodePort) | HTTP |

## Ports

- **9333**: Master server (cluster management, volume assignment)
- **8080**: Volume server (blob storage)
- **8888**: Filer (POSIX-like file interface)
- **8333**: S3 gateway (S3-compatible API)

## Networking / Firewall

The following ports must be opened at the firewall or load balancer level:

| Port | Protocol | Purpose | When |
|------|----------|---------|------|
| **443** | HTTPS | Filer via Traefik Gateway | SSL enabled |
| **80** | HTTP | Redirects to HTTPS (301) | SSL enabled |
| **30833** | TCP | S3 API (NodePort) | Always |
| **30888** | TCP | Filer (NodePort) | Always |
| **30933** | TCP | Master (NodePort) | Always |

## Version Update

1. Check available tags at Docker Hub: `chrislusf/seaweedfs`
2. Update `versions` array in `app.yaml`
3. Run `make validate && make lint && make catalog`
4. Test with `make test-integration` if available

## Notes

- SeaweedFS replaces MinIO (archived Feb 2026). Provides S3-compatible API.
- No authentication by default; suitable for internal/private network use.
- License: Apache 2.0 (fully open-source).
