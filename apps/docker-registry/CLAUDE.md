# Docker Registry — App-Level CLAUDE.md

## Architecture

- **Type**: Single-tier (registry server)
- **Components**: Docker Registry (OCI-compliant container image registry)
- **Deploy method**: Manifest (raw K8s YAML + envsubst)
- **Storage**: PVC via `local-path` StorageClass

## Components

| Component | Image | Role |
|-----------|-------|------|
| Registry | `docker.io/library/registry` | OCI-compliant container image storage and distribution |

## Parameters

| Parameter | Default | Effect |
|-----------|---------|--------|
| `REGISTRY_DATA_SIZE` | `50Gi` | PVC size for image storage |
| `REGISTRY_HTTP_SECRET` | (auto-generated) | Secret key for HTTP session signing |

## Health Check

1. HTTP GET `http://localhost:5000/v2/` — registry V2 API responding
2. HTTP GET `http://localhost:5000/v2/_catalog` — catalog endpoint accessible
3. PVC bound status verification

## Access

| Endpoint | Port | Protocol |
|----------|------|----------|
| Registry API | 30500 (NodePort) | HTTP |

## Version Update

1. Check available tags at Docker Hub: `library/registry`
2. Update `versions` array in `app.yaml`
3. Run `make validate && make lint && make catalog`
4. Test with `make test-integration` if available

## Notes

- No authentication by default; suitable for internal/private network use.
- To push images: `docker push <VM-IP>:30500/<image>:<tag>`
- For Docker client access, add `<VM-IP>:30500` to insecure registries in Docker daemon config.
- License: Apache 2.0 (fully open-source).
