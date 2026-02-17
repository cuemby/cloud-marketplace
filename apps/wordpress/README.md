# WordPress

WordPress deployment for Cuemby Cloud Marketplace.

## Overview

Deploys WordPress using the [Bitnami WordPress Helm chart](https://github.com/bitnami/charts/tree/main/bitnami/wordpress) with Cuemby-specific defaults optimized for single-node K3s clusters.

## Parameters

| Parameter | Env Variable | Required | Default | Description |
|-----------|-------------|----------|---------|-------------|
| Admin Username | `PARAM_WORDPRESS_USERNAME` | Yes | `admin` | WordPress admin username |
| Admin Password | `PARAM_WORDPRESS_PASSWORD` | Yes | — | WordPress admin password |
| Admin Email | `PARAM_WORDPRESS_EMAIL` | Yes | `admin@example.com` | WordPress admin email |
| Blog Name | `PARAM_WORDPRESS_BLOG_NAME` | No | `My Cuemby Blog` | Site title |
| First Name | `PARAM_WORDPRESS_FIRST_NAME` | No | `Admin` | Admin first name |
| Last Name | `PARAM_WORDPRESS_LAST_NAME` | No | `User` | Admin last name |
| DB Root Password | `PARAM_MARIADB_ROOT_PASSWORD` | Yes | — | MariaDB root password |
| DB Password | `PARAM_MARIADB_PASSWORD` | Yes | — | MariaDB WordPress user password |

## Access

After deployment:
- **Site**: `http://<VM_IP>:30080`
- **Admin**: `http://<VM_IP>:30080/wp-admin`

## Cloud-Init

Two user-data formats are provided — use whichever your cloud provider supports:

| Format | File | When to use |
|--------|------|-------------|
| YAML (cloud-config) | [`cloud-init.yaml`](cloud-init.yaml) | AWS, GCP, Azure, and most providers that support cloud-init |
| Bash script | [`cloud-init.sh`](cloud-init.sh) | Providers that only accept a raw bash script as user-data |

Copy the appropriate file, replace the `CHANGE_ME` passwords, and pass it as user-data when creating a VM:

```bash
# YAML format (most providers)
cp apps/wordpress/cloud-init.yaml user-data.yaml

# OR bash format (providers without cloud-init YAML support)
cp apps/wordpress/cloud-init.sh user-data.sh
```

See the [main README](../../README.md#usage) for AWS, GCP, and Azure examples.

## Requirements

- CPU: 2 cores
- Memory: 4 GB
- Disk: 20 GB

## Profiles

- **values.yaml** — Standard defaults (NodePort, local-path storage)
- **values-single.yaml** — Minimal profile for smaller VMs
