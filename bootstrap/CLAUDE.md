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
2. `install-k3s.sh` — K3s installation
3. `install-helm.sh` — Helm installation
4. `deploy-app.sh` — app deployment
5. `healthcheck.sh` — post-deploy verification

## Key Paths (on target VM)

- Repo checkout: `/opt/cuemby/marketplace`
- Logs: `/var/log/cuemby/bootstrap.log`
- State file: `/var/lib/cuemby/marketplace-state.json`
- Kubeconfig: `/etc/rancher/k3s/k3s.yaml`
