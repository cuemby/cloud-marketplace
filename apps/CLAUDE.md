# apps/

Application catalog. Each subdirectory is a deployable application.

> **Full deployment pattern documented in [RFD 0001](../.claude/rfd/0001.md).**

## Deployment Methods

Three deployment methods are supported. See the decision framework in RFD 0001 for guidance on which to use.

| Method                   | `deployMethod` | Template               | Deploy Script                  |
| ------------------------ | -------------- | ---------------------- | ------------------------------ |
| Helm wrapper chart       | `helm`         | `_template/`           | `bootstrap/deploy-helm.sh`     |
| Raw manifests (envsubst) | `manifest`     | `_template-manifest/`  | `bootstrap/deploy-manifest.sh` |
| Kustomize overlays       | `kustomize`    | `_template-kustomize/` | `bootstrap/deploy-kustomize.sh`|

## Application Structure

Every app MUST have:

```text
apps/<name>/
├── app.yaml           # Metadata, versions, parameters, deploy method
├── cloud-init.yaml    # Cloud-init YAML format
├── cloud-init.sh      # Bash user-data format
├── hooks/
│   ├── pre-install.sh   # Credential generation, parameter defaults
│   ├── post-install.sh  # Post-deploy setup
│   └── healthcheck.sh   # App-specific health verification
└── chart/ | manifests/ | kustomize/   # Deploy artifacts (one of)
```

## app.yaml Schema

Common fields (all methods):

- `name` — unique identifier (matches directory name)
- `displayName` — human-readable name
- `description` — short description
- `category` — app category (cms, database, monitoring, ci-cd, etc.)
- `deployMethod` — `helm`, `manifest`, or `kustomize`
- `ssl.enabled` — `true`/`false` (cert-manager auto-provisioning)
- `requirements` — minimum VM resources (`cpu`, `memory`, `disk`)
- `versions[]` — multi-version support with `appVersion` + method-specific key:
  - Helm: `chartVersion` (dependency version)
  - Manifest/Kustomize: `imageTag` (Docker image tag)
- `parameters[]` — user-configurable parameters (`name`, `type`, `default`, etc.)

Method-specific fields:

- **Helm:** `chart.name`, `chart.repository`, `chart.version`, `parameters[].helmMapping`
- **Manifest:** `manifests.path`
- **Kustomize:** `kustomize.basePath`, `kustomize.overlaysPath`

## Adding a New App

```bash
# Helm (default)
make new-app NAME=myapp

# Raw manifests
make new-app NAME=myapp METHOD=manifest

# Kustomize
make new-app NAME=myapp METHOD=kustomize
```

## Conventions

- Parameters use `PARAM_*` prefix at runtime (declared without prefix in `app.yaml`)
- Credentials auto-generated in `hooks/pre-install.sh` if not provided
- Credentials stored as Kubernetes Secrets (never plaintext in Deployments)
- Manifest files use numeric prefixes for ordering (`00-secrets.yaml`, `10-pvc.yaml`, etc.)
- Hooks are sourced (not subshelled) so exports propagate
- All images must be 100% open source — verify license before use
