# Redis

Redis deployment for Cuemby Cloud Marketplace.

## Overview

Deploys Redis using the [Bitnami Redis Helm chart](https://github.com/bitnami/charts/tree/main/bitnami/redis) with Cuemby-specific defaults optimized for single-node K3s clusters.

## Parameters

| Parameter | Env Variable | Required | Default | Description |
|-----------|-------------|----------|---------|-------------|
| Redis Password | `PARAM_REDIS_PASSWORD` | Yes | — | Redis authentication password |

## Access

After deployment:
- **Redis CLI**: `redis-cli -h <VM_IP> -p 30379 -a <password>`

## Cloud-Init

Two user-data formats are provided — use whichever your cloud provider supports:

| Format | File | When to use |
|--------|------|-------------|
| YAML (cloud-config) | [`cloud-init.yaml`](cloud-init.yaml) | AWS, GCP, Azure, and most providers that support cloud-init |
| Bash script | [`cloud-init.sh`](cloud-init.sh) | Providers that only accept a raw bash script as user-data |

Copy the appropriate file, set the required password, and pass it as user-data when creating a VM. The required password (marked with `:?`) will fail with a clear error if not set.

```bash
# YAML format (most providers)
cp apps/redis/cloud-init.yaml user-data.yaml

# OR bash format (providers without cloud-init YAML support)
cp apps/redis/cloud-init.sh user-data.sh
```

See the [main README](../../README.md#usage) for AWS, GCP, and Azure examples.

## Requirements

- CPU: 1 core
- Memory: 2 GB
- Disk: 10 GB

## Profiles

- **values.yaml** — Standard defaults (NodePort, local-path storage)
- **values-single.yaml** — Minimal profile for smaller VMs
