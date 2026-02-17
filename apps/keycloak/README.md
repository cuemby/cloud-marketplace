# Keycloak

Keycloak deployment for Cuemby Cloud Marketplace.

## Overview

Deploys Keycloak using the [Bitnami Keycloak Helm chart](https://github.com/bitnami/charts/tree/main/bitnami/keycloak) with Cuemby-specific defaults optimized for single-node K3s clusters. Includes a bundled PostgreSQL database.

## Parameters

| Parameter | Env Variable | Required | Default | Description |
|-----------|-------------|----------|---------|-------------|
| Admin Username | `PARAM_KEYCLOAK_ADMIN_USER` | Yes | `user` | Keycloak administrator username |
| Admin Password | `PARAM_KEYCLOAK_ADMIN_PASSWORD` | Yes | — | Keycloak administrator password |
| PostgreSQL Password | `PARAM_KEYCLOAK_POSTGRES_PASSWORD` | Yes | — | Password for the bundled PostgreSQL database |

## Access

After deployment:
- **Admin Console**: `http://<VM_IP>:30880`

## Cloud-Init

Two user-data formats are provided — use whichever your cloud provider supports:

| Format | File | When to use |
|--------|------|-------------|
| YAML (cloud-config) | [`cloud-init.yaml`](cloud-init.yaml) | AWS, GCP, Azure, and most providers that support cloud-init |
| Bash script | [`cloud-init.sh`](cloud-init.sh) | Providers that only accept a raw bash script as user-data |

Copy the appropriate file, set the required passwords, and pass it as user-data when creating a VM. The required passwords (marked with `:?`) will fail with a clear error if not set.

```bash
# YAML format (most providers)
cp apps/keycloak/cloud-init.yaml user-data.yaml

# OR bash format (providers without cloud-init YAML support)
cp apps/keycloak/cloud-init.sh user-data.sh
```

See the [main README](../../README.md#usage) for AWS, GCP, and Azure examples.

## Requirements

- CPU: 2 cores
- Memory: 4 GB
- Disk: 20 GB

## Profiles

- **values.yaml** — Standard defaults (NodePort, local-path storage, bundled PostgreSQL)
- **values-single.yaml** — Minimal profile for smaller VMs
