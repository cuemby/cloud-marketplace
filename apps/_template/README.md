# APPNAME

APPNAME deployment for Cuemby Cloud Marketplace.

## Overview

Deploys APPNAME using the [upstream chart](UPSTREAM_URL) with Cuemby-specific defaults.

## Parameters

| Parameter | Env Variable | Required | Default | Description |
|-----------|-------------|----------|---------|-------------|
| Example | `PARAM_EXAMPLE_PARAM` | No | `example` | Example parameter |

## Access

After deployment:
- **Service**: `http://<VM_IP>:30080`

## Cloud-Init

Two user-data formats are provided — use whichever your cloud provider supports:

| Format | File | When to use |
|--------|------|-------------|
| YAML (cloud-config) | [`cloud-init.yaml`](cloud-init.yaml) | AWS, GCP, Azure, and most providers that support cloud-init |
| Bash script | [`cloud-init.sh`](cloud-init.sh) | Providers that only accept a raw bash script as user-data |

Copy the appropriate file, set the required parameters, and pass it as user-data when creating a VM. Optional parameters use sensible defaults; required ones (marked with `:?`) will fail with a clear error if not set. See the [main README](../../README.md#usage) for provider-specific examples.

## Requirements

- CPU: 2 cores
- Memory: 4 GB
- Disk: 20 GB
