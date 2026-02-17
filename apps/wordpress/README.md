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

A ready-to-use cloud-init file is provided at [`cloud-init.yaml`](cloud-init.yaml). Copy it, replace the `CHANGE_ME` passwords, and pass it as user-data when creating a VM:

```bash
cp apps/wordpress/cloud-init.yaml user-data.yaml
# Edit user-data.yaml — set your passwords
# Then launch a VM (see main README for provider-specific commands)
```

See the [main README](../../README.md#usage) for AWS, GCP, and Azure examples.

## Requirements

- CPU: 2 cores
- Memory: 4 GB
- Disk: 20 GB

## Profiles

- **values.yaml** — Standard defaults (NodePort, local-path storage)
- **values-single.yaml** — Minimal profile for smaller VMs
