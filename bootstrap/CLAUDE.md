# bootstrap/

VM bootstrap system. Scripts in this directory run on freshly provisioned VMs via cloud-init.

## Conventions

- **Pure bash** — no Python/Go/Node dependencies (only curl, git, jq, yq)
- **ShellCheck compliant** — all scripts must pass `shellcheck -x -S warning`
- All scripts source `lib/*.sh` for shared functionality
- Use `set -euo pipefail` in every script
- Use `readonly` for constants, `local` for function variables
- Log via `lib/logging.sh` functions (`log_info`, `log_error`, etc.), never raw `echo`
- Write state transitions via `lib/cleanup.sh:write_state`, never directly
- Scripts run as root on the target VM

## Execution Order

1. `entrypoint.sh` — orchestrator (called by cloud-init)
2. `install-k3s.sh` — K3s installation (Traefik disabled, `local-path` StorageClass)
3. `install-helm.sh` — Helm 3 installation
4. `deploy-app.sh` — multi-method app deployment (dispatches to method-specific script)
5. `healthcheck.sh` — post-deploy verification (generic + app-specific hooks)
6. `install-ssl.sh` — optional cert-manager setup (when `ssl.enabled: true`)

## Deployment Scripts

`deploy-app.sh` reads `app.yaml` and dispatches to the correct deploy script:

| `deployMethod` | Script                | Description                              |
| -------------- | --------------------- | ---------------------------------------- |
| `helm`         | `deploy-helm.sh`      | Helm wrapper chart (upstream dependency) |
| `manifest`     | `deploy-manifest.sh`  | Raw YAML + envsubst variable expansion   |
| `kustomize`    | `deploy-kustomize.sh` | Kustomize base + overlays                |

### Deploy Flow (all methods)

1. Resolve app version (default or `APP_VERSION`)
2. Create namespace `app-<name>`
3. Source `hooks/pre-install.sh` (exports `PARAM_*` with generated credentials/defaults)
4. Deploy artifacts (method-specific)
5. Source `hooks/post-install.sh`

### Version Resolution

- `deploy-app.sh` matches `APP_VERSION` against `versions[].appVersion` in `app.yaml`
- Extracts `imageTag` (manifest/kustomize) or `chartVersion` (Helm)
- Falls back to the entry with `default: true` if `APP_VERSION` is unset

## Shared Libraries (`lib/`)

| File               | Purpose                                             |
| ------------------ | --------------------------------------------------- |
| `constants.sh`     | State machine values, timeouts, default paths       |
| `logging.sh`       | `log_info`, `log_error`, `log_warn`, `log_section`  |
| `validation.sh`    | `validate_required_env`, `validate_app_exists`, etc |
| `retry.sh`         | `retry_command` with configurable attempts/backoff  |
| `cleanup.sh`       | `write_state`, `on_error`, `on_exit` trap handlers  |
| `network.sh`       | Port checks, service endpoint validation            |
| `deploy-helpers.sh`| Shared deploy utilities (namespace, version parsing)|
| `ssl-hooks.sh`     | cert-manager integration, certificate provisioning  |

## Key Paths (on target VM)

- Repo checkout: `/opt/cuemby/marketplace`
- Apps directory: `/opt/cuemby/marketplace/apps`
- Logs: `/var/log/cuemby/bootstrap.log`
- State file: `/var/lib/cuemby/marketplace-state.json`
- Kubeconfig: `/etc/rancher/k3s/k3s.yaml`

## Key Paths (E2E/local testing)

- Repo root: `$MARKETPLACE_DIR` (auto-set by `tests/e2e/run-e2e.sh`)
- Logs: `.e2e-logs/`
- State: `.e2e-state/`
- Kubeconfig: `~/.kube/config` (k3d context: `k3d-e2e-test`)
