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

A ready-to-use cloud-init file is provided at [`cloud-init.yaml`](cloud-init.yaml). Copy it, replace the `CHANGE_ME` values, and pass it as user-data when creating a VM. See the [main README](../../README.md#usage) for provider-specific examples.

## Requirements

- CPU: 2 cores
- Memory: 4 GB
- Disk: 20 GB
