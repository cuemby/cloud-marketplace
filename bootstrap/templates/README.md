# Cloud-Init Integration Guide

This document explains how the Cuemby Cloud UI generates cloud-init user-data to provision VMs with marketplace applications.

## How It Works

1. User selects an application and fills in parameters in the UI
2. UI generates cloud-init user-data from `cloud-init.yaml.tpl`
3. VM is provisioned with the user-data
4. On first boot, cloud-init clones this repo and runs the bootstrap
5. UI polls the state file to track progress

## Generating User-Data

The UI replaces template placeholders in `cloud-init.yaml.tpl`:

| Placeholder | Source | Example |
|-------------|--------|---------|
| `{{ app_name }}` | Selected application | `wordpress` |
| `{{ app_version }}` | Selected version (or default) | `24.1.7` |
| `{{ parameters }}` | User-provided values | See below |

### Parameter Passing

Parameters are passed as `PARAM_*` environment variables. The UI should generate one `export` line per parameter:

```bash
export PARAM_WORDPRESS_USERNAME="admin"
export PARAM_WORDPRESS_PASSWORD="secretpassword"
export PARAM_WORDPRESS_EMAIL="admin@example.com"
export PARAM_MARIADB_ROOT_PASSWORD="rootpassword"
export PARAM_MARIADB_PASSWORD="wpdbpassword"
```

The parameter names come from the `parameters[].name` field in each app's `app.yaml`.

## State File

The bootstrap writes progress to `/var/lib/cuemby/marketplace-state.json`. The UI should poll this file (e.g., via SSH or cloud provider API) to show deployment progress.

### State Machine

```
preparing → validating → installing_k3s → installing_helm → deploying → healthcheck → ready
                                                                                     ↘ error
```

### State File Format

```json
{
  "phase": "ready",
  "timestamp": "2026-02-17T12:00:00Z",
  "app": "wordpress",
  "version": "24.1.7"
}
```

On error:

```json
{
  "phase": "error",
  "timestamp": "2026-02-17T12:05:00Z",
  "app": "wordpress",
  "version": "24.1.7",
  "error": "Error in deploy-app.sh at line 42"
}
```

### Polling Recommendations

- **Interval**: Every 10 seconds
- **Timeout**: 15 minutes (covers full bootstrap)
- **Success**: `phase == "ready"`
- **Failure**: `phase == "error"` (show `error` field to user)

## VM Requirements

| Resource | Minimum |
|----------|---------|
| OS | Ubuntu 22.04 LTS (recommended) |
| CPU | Per app `requirements.cpu` |
| Memory | Per app `requirements.memory` |
| Disk | Per app `requirements.disk` |
| Network | Outbound HTTPS (for package install, chart pulls) |

## Supported Cloud Providers

The cloud-init format is provider-agnostic and works on:

- **AWS** — EC2 user-data
- **GCP** — Compute Engine startup-script metadata
- **Azure** — VM custom data
- **DigitalOcean** — Droplet user-data
- **Any provider** supporting cloud-init
