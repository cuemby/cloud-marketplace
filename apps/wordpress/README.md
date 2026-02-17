# WordPress

WordPress deployment for Cuemby Cloud Marketplace with automatic SSL via Let's Encrypt.

## Overview

Deploys WordPress using the [Bitnami WordPress Helm chart](https://github.com/bitnami/charts/tree/main/bitnami/wordpress) with Cuemby-specific defaults optimized for single-node K3s clusters.

### Architecture

```text
Port 80  -> Traefik (Gateway "web")       -> HTTP-to-HTTPS redirect
Port 443 -> Traefik (Gateway "websecure") -> WordPress ClusterIP -> Pod

cert-manager watches Gateway annotation -> provisions Let's Encrypt cert -> stores in Secret
Traefik auto-loads cert from Secret via Gateway TLS config
```

- **Traefik** (bundled with K3s) serves as the Gateway API controller
- **cert-manager** provisions TLS certificates via Let's Encrypt HTTP-01
- **sslip.io** provides zero-config DNS (`<IP>.sslip.io` resolves to the VM's public IP)
- The VM's public IP is auto-detected at runtime via `curl ifconfig.me` (with fallbacks)

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

### SSL Parameters

These are not in `app.yaml` (they bypass Helm). Set them as environment variables:

| Env Variable                | Required | Default                | Description                                    |
|-----------------------------|----------|------------------------|------------------------------------------------|
| `PARAM_WORDPRESS_HOSTNAME`  | No       | Auto-detected sslip.io | Custom domain (skip IP detection)              |
| `ACME_EMAIL`                | No       | `PARAM_WORDPRESS_EMAIL`| Email for Let's Encrypt registration           |
| `ACME_USE_STAGING`          | No       | `false`                | Use Let's Encrypt staging (avoids rate limits) |

## Access

After deployment:

- **Site**: `https://<HOSTNAME>` (see `bootstrap.log` for exact URL)
- **Admin**: `https://<HOSTNAME>/wp-admin`

The TLS certificate is provisioned automatically. It may take 60-120 seconds after deployment.

### Custom Domain

To use your own domain instead of sslip.io:

1. Set `PARAM_WORDPRESS_HOSTNAME=example.com` before deployment
2. Point your domain's DNS A record to the VM's public IP
3. Ensure ports 80 and 443 are open (cert-manager needs port 80 for HTTP-01 validation)

## Cloud-Init

Two user-data formats are provided — use whichever your cloud provider supports:

| Format | File | When to use |
|--------|------|-------------|
| YAML (cloud-config) | [`cloud-init.yaml`](cloud-init.yaml) | AWS, GCP, Azure, and most providers that support cloud-init |
| Bash script | [`cloud-init.sh`](cloud-init.sh) | Providers that only accept a raw bash script as user-data |

Copy the appropriate file, set the required passwords, and pass it as user-data when creating a VM. Optional parameters use sensible defaults; required passwords (marked with `:?`) will fail with a clear error if not set.

```bash
# YAML format (most providers)
cp apps/wordpress/cloud-init.yaml user-data.yaml

# OR bash format (providers without cloud-init YAML support)
cp apps/wordpress/cloud-init.sh user-data.sh
```

See the [main README](../../README.md#usage) for AWS, GCP, and Azure examples.

## Firewall

Allow inbound TCP on ports **80** and **443** (not 30080/30443).

## Requirements

- CPU: 2 cores
- Memory: 4 GB (Traefik ~100MB + cert-manager ~120MB overhead)
- Disk: 20 GB

## Verification

```bash
# Check deployment state
cat /var/lib/cuemby/marketplace-state.json

# Check Gateway status
kubectl get gateway -n app-wordpress

# Check HTTPRoute
kubectl get httproute -n app-wordpress

# Check certificate
kubectl describe certificate -n app-wordpress

# Check cert-manager logs
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager
```

## Profiles

- **values.yaml** — Standard defaults (ClusterIP, Traefik Gateway routing, local-path storage)
- **values-single.yaml** — Minimal profile for smaller VMs
