# Cuemby Cloud Marketplace

Public repository powering application deployments on Cuemby Cloud. When a user selects an application from the Cuemby Cloud UI, a VM is provisioned with cloud-init user-data that clones this repo and runs a bootstrap script to install K3s, Helm, and the selected application.

## How It Works

```
User selects app in UI
  → VM provisioned with cloud-init user-data
    → user-data clones this repo to /opt/cuemby/marketplace
      → runs bootstrap/entrypoint.sh with PARAM_* env vars
        → Validates inputs
        → Installs K3s (single-node)
        → Installs Helm
        → Deploys app via wrapper Helm chart
        → Runs health checks
        → Writes "ready" state file
```

The bootstrap system is provider-agnostic (AWS, GCP, Azure) and uses only bash — no Go/Python dependencies required on the VM.

## Usage

Deploy any application from the catalog onto a VM using cloud-init. The examples below use WordPress, but the same pattern applies to every app in `apps/`.

### Prerequisites

| Requirement | Details |
|-------------|---------|
| VM OS | Ubuntu 22.04 LTS (recommended) |
| VM Size | Per app `requirements` in `app.yaml` (WordPress: 2 CPU, 4Gi RAM, 20Gi disk) |
| Network | Outbound HTTPS (port 443) for package installs and chart pulls |
| Firewall | Inbound TCP on ports **30080** (HTTP) and **30443** (HTTPS) for app access |
| Cloud-init | Supported by your cloud provider |

### Step 1: Create the Cloud-Init User-Data File

Each app includes two user-data formats — use whichever your cloud provider supports:

| Format | File | When to use |
|--------|------|-------------|
| YAML (cloud-config) | `cloud-init.yaml` | AWS, GCP, Azure, and most providers that support cloud-init |
| Bash script | `cloud-init.sh` | Providers that only accept a raw bash script as user-data |

Copy the appropriate file and set the required passwords. Optional parameters use sensible defaults; required passwords (marked with `:?`) will fail with a clear error if not set:

```bash
# YAML format (most providers)
cp apps/wordpress/cloud-init.yaml user-data.yaml

# OR bash format (providers without cloud-init YAML support)
cp apps/wordpress/cloud-init.sh user-data.sh
```

See [`apps/wordpress/cloud-init.yaml`](apps/wordpress/cloud-init.yaml) and [`apps/wordpress/cloud-init.sh`](apps/wordpress/cloud-init.sh) for the full files. Every app in `apps/` follows the same pattern.

> **Security note**: Cloud-init user-data is typically stored in the instance metadata. For production use, consider rotating passwords after deployment or using your provider's secrets manager.

### Step 2: Launch a VM with the User-Data

#### AWS (EC2)

```bash
aws ec2 run-instances \
  --image-id ami-0c7217cdde317cfec \
  --instance-type t3.medium \
  --key-name my-key \
  --security-group-ids sg-xxxxxxxx \
  --user-data file://user-data.yaml \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":20}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=wordpress-marketplace}]'
```

Replace the AMI with the latest Ubuntu 22.04 for your region. Ensure the security group allows inbound TCP on ports 22, 30080, and 30443.

#### GCP (Compute Engine)

```bash
gcloud compute instances create wordpress-marketplace \
  --zone=us-central1-a \
  --machine-type=e2-medium \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=20GB \
  --metadata-from-file=user-data=user-data.yaml \
  --tags=http-server,https-server
```

Create a firewall rule for the NodePorts: `gcloud compute firewall-rules create allow-nodeport --allow=tcp:30080,tcp:30443 --target-tags=http-server`

#### Azure (Virtual Machines)

```bash
az vm create \
  --resource-group myResourceGroup \
  --name wordpress-marketplace \
  --image Canonical:0001-com-ubuntu-server-jammy:22_04-lts:latest \
  --size Standard_B2s \
  --admin-username azureuser \
  --generate-ssh-keys \
  --custom-data user-data.yaml
```

Open the NodePort ports: `az vm open-port --resource-group myResourceGroup --name wordpress-marketplace --port 30080 --priority 1001`

#### Other Providers

Any cloud provider that supports cloud-init can use the same `user-data.yaml` file. Look for "user-data", "cloud-init", or "startup script" in your provider's VM creation docs.

### Step 3: Monitor Deployment Progress

The bootstrap takes approximately 5-10 minutes. SSH into the VM to monitor:

```bash
# Watch the state file (updates at each phase)
ssh user@<VM_IP> 'watch -n5 cat /var/lib/cuemby/marketplace-state.json'

# Or tail the full bootstrap log
ssh user@<VM_IP> 'tail -f /var/log/cuemby/bootstrap.log'
```

The deployment progresses through these phases:

```text
preparing → validating → installing_k3s → installing_helm → deploying → healthcheck → ready
```

A successful deployment ends with:

```json
{
  "phase": "ready",
  "app": "wordpress",
  "version": "28.1.9"
}
```

If something goes wrong, the state file shows `"phase": "error"` with a description. Check `/var/log/cuemby/bootstrap.log` for details.

### Step 4: Access the Application

Once the state file shows `"phase": "ready"`:

- **HTTP**: `http://<VM_PUBLIC_IP>:30080`
- **HTTPS**: `https://<VM_PUBLIC_IP>:30443` (self-signed certificate)

Log in at `http://<VM_PUBLIC_IP>:30080/wp-admin` with the username and password from your user-data file.

> **Tip**: Inspect the Kubernetes cluster directly:
>
> ```bash
> ssh user@<VM_IP> 'sudo kubectl get pods -n app-wordpress'
> ssh user@<VM_IP> 'sudo kubectl get svc -n app-wordpress'
> ```

### Deploying Other Applications

To deploy a different app, change `APP_NAME`, `APP_VERSION`, and `PARAM_*` in the user-data file. Check the app's `app.yaml` for available parameters:

| Field | Where to find it |
|-------|-----------------|
| App name | Directory name under `apps/` |
| Available versions | `versions` list in `apps/<name>/app.yaml` |
| Required parameters | `parameters` with `required: true` in `apps/<name>/app.yaml` |
| VM sizing | `requirements` in `apps/<name>/app.yaml` |

## Quick Start

### Prerequisites

- [ShellCheck](https://github.com/koalaman/shellcheck) (linting)
- [Helm](https://helm.sh/) (chart linting and testing)
- [bats-core](https://github.com/bats-core/bats-core) (testing)
- [yq](https://github.com/mikefarah/yq) (YAML processing)

### Common Commands

```bash
make help              # Show all available targets
make lint              # ShellCheck all scripts
make lint-charts       # Helm lint all charts
make test              # Run unit tests
make test-integration  # Run integration tests (Docker required)
make catalog           # Generate catalog.json
make validate          # Validate all app.yaml files
make new-app NAME=foo  # Scaffold a new app
```

## Adding a New Application

```bash
make new-app NAME=myapp
```

This copies `apps/_template/` to `apps/myapp/` and opens the scaffolded files for editing. See [apps/README.md](apps/_template/README.md) for the full guide.

### App Structure

```
apps/myapp/
├── app.yaml           # Metadata, parameters, helm mappings
├── cloud-init.yaml    # Cloud-init user-data (YAML format)
├── cloud-init.sh      # Cloud-init user-data (bash script format)
├── chart/             # Wrapper Helm chart (depends on upstream)
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
├── hooks/             # Lifecycle hooks (pre-install, post-install, healthcheck)
└── README.md
```

## Environment Variables

The bootstrap accepts parameters as `PARAM_*` environment variables. These are mapped to Helm `--set` flags via the `helmMapping` field in each app's `app.yaml`.

| Variable | Required | Description |
|----------|----------|-------------|
| `APP_NAME` | Yes | Application to deploy (e.g., `wordpress`) |
| `APP_VERSION` | No | App version (defaults to latest in app.yaml) |
| `PARAM_*` | Varies | App-specific parameters (see each app's app.yaml) |

## State File

The bootstrap writes progress to `/var/lib/cuemby/marketplace-state.json`:

```
preparing → validating → installing_k3s → installing_helm → deploying → healthcheck → ready
```

Each state includes timestamp, app name, version, and error details if applicable. The UI polls this file to show deployment progress.

## Project Structure

```
cloud-marketplace/
├── bootstrap/          # VM bootstrap system
│   ├── entrypoint.sh   # Main entry point
│   ├── install-k3s.sh  # K3s installation
│   ├── install-helm.sh # Helm installation
│   ├── deploy-app.sh   # App deployment
│   ├── healthcheck.sh  # Post-deploy verification
│   ├── lib/            # Shared bash libraries
│   └── templates/      # Cloud-init templates
├── apps/               # Application catalog
│   ├── wordpress/      # Reference implementation
│   └── _template/      # Skeleton for new apps
├── catalog/            # Generated catalog (catalog.json)
├── scripts/            # Dev and CI tooling
├── tests/              # Test suites (bats-core)
└── .github/workflows/  # CI/CD
```

## License

Copyright (c) Cuemby, Inc. All rights reserved.
