# OpenBao — App-Level CLAUDE.md

## Architecture

- **Type**: Single-tier (secrets management server)
- **Components**: OpenBao (community fork of HashiCorp Vault)
- **Deploy method**: Manifest (raw K8s YAML + envsubst)
- **Storage**: PVC via `local-path` StorageClass
- **Mode**: Dev mode (auto-initialized, auto-unsealed, in-memory + file storage)

## Components

| Component | Image | Role |
|-----------|-------|------|
| OpenBao | `quay.io/openbao/openbao` | Secrets management, identity, and encryption |

## Parameters

| Parameter | Default | Effect |
|-----------|---------|--------|
| `OPENBAO_DATA_SIZE` | `10Gi` | PVC size for data storage |
| `OPENBAO_DEV_ROOT_TOKEN` | (auto-generated) | Root token for dev mode API access |

## Health Check

1. HTTP GET `http://localhost:8200/v1/sys/health` — health endpoint (200=initialized+unsealed)
2. GET `/v1/sys/mounts` with root token — secrets engine accessible
3. PVC bound status verification

## Access

| Endpoint | Port | Protocol |
|----------|------|----------|
| API / Web UI | 30820 (NodePort) | HTTP |

## Version Update

1. Check available tags at Quay.io: `openbao/openbao`
2. Update `versions` array in `app.yaml`
3. Run `make validate && make lint && make catalog`
4. Test with `make test-integration` if available

## Notes

- Runs in **dev mode** by default — auto-initialized and auto-unsealed on startup.
- Dev mode is suitable for development, testing, and single-node deployments.
- The root token is auto-generated and stored in a Kubernetes Secret.
- OpenBao is a community fork of HashiCorp Vault (MPL 2.0 license).
- API is compatible with Vault — use `VAULT_ADDR` and `VAULT_TOKEN` env vars with the `bao` CLI.
- `disable_mlock = true` in config since mlock is not required in containerized environments.
- License: MPL 2.0 (fully open-source).
