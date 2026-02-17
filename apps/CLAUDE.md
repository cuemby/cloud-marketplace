# apps/

Application catalog. Each subdirectory is a deployable application.

## Conventions

- Each app has its own directory under `apps/`
- `_template/` is the skeleton — copy it for new apps via `scripts/new-app.sh`
- Every app MUST have an `app.yaml` with metadata, parameters, and helmMappings
- Wrapper Helm charts depend on upstream charts (never fork upstream)
- Hooks are optional bash scripts in `hooks/` (pre-install, post-install, healthcheck)

## app.yaml Schema

Required fields:
- `name` — unique identifier (matches directory name)
- `displayName` — human-readable name
- `description` — short description
- `category` — app category (cms, database, monitoring, etc.)
- `chart.name` — upstream chart name
- `chart.repository` — upstream chart repository URL
- `chart.version` — pinned upstream chart version
- `requirements` — minimum VM resources (cpu, memory, disk)
- `parameters` — list of configurable parameters with helmMapping

## Adding a New App

```bash
make new-app NAME=myapp
# Then edit apps/myapp/app.yaml and apps/myapp/chart/values.yaml
```
