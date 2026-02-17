# PostgreSQL

PostgreSQL deployment for Cuemby Cloud Marketplace.

## Overview

Deploys PostgreSQL using the [Bitnami PostgreSQL Helm chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql) with Cuemby-specific defaults optimized for single-node K3s clusters.

## Parameters

| Parameter | Env Variable | Required | Default | Description |
|-----------|-------------|----------|---------|-------------|
| Admin Password | `PARAM_POSTGRES_PASSWORD` | Yes | — | Password for the postgres admin user |
| Custom Username | `PARAM_POSTGRES_USERNAME` | No | — | Name for an optional custom user |
| Custom User Password | `PARAM_POSTGRES_USER_PASSWORD` | No | — | Password for the optional custom user |
| Database Name | `PARAM_POSTGRES_DATABASE` | No | — | Name for an optional custom database |

## Access

After deployment:
- **psql**: `psql -h <VM_IP> -p 30432 -U postgres`

## Cloud-Init

Two user-data formats are provided — use whichever your cloud provider supports:

| Format | File | When to use |
|--------|------|-------------|
| YAML (cloud-config) | [`cloud-init.yaml`](cloud-init.yaml) | AWS, GCP, Azure, and most providers that support cloud-init |
| Bash script | [`cloud-init.sh`](cloud-init.sh) | Providers that only accept a raw bash script as user-data |

Copy the appropriate file, set the required password, and pass it as user-data when creating a VM. The required password (marked with `:?`) will fail with a clear error if not set. Optional parameters for custom user/database can be left empty.

```bash
# YAML format (most providers)
cp apps/postgresql/cloud-init.yaml user-data.yaml

# OR bash format (providers without cloud-init YAML support)
cp apps/postgresql/cloud-init.sh user-data.sh
```

See the [main README](../../README.md#usage) for AWS, GCP, and Azure examples.

## Requirements

- CPU: 1 core
- Memory: 2 GB
- Disk: 20 GB

## Profiles

- **values.yaml** — Standard defaults (NodePort, local-path storage)
- **values-single.yaml** — Minimal profile for smaller VMs
