# tests/

Test suites for the cloud marketplace.

## Test Types

| Directory      | Framework | Description                          | Requirements     |
| -------------- | --------- | ------------------------------------ | ---------------- |
| `unit/`        | bats-core | Unit tests for bash library functions| None (fast)      |
| `integration/` | bats-core | Full bootstrap tests                 | Docker           |
| `e2e/`         | bash      | End-to-end app deployment tests      | Docker (k3d)     |

## Running Tests

```bash
make test                                  # Unit tests only
make test-unit                             # Same as above
make test-integration                      # Docker required
make test-e2e APP=wordpress                # E2E for all versions of an app
make test-e2e APP=wordpress VERSION=6.9.1  # E2E for a specific version
bats tests/unit/                           # Direct bats invocation
```

## Unit Tests (`unit/`)

- Test file naming: `test_<module>.bats`
- Use `bats` assertions: `[ "$status" -eq 0 ]`, `[[ "$output" =~ pattern ]]`
- Each test must be independent (no shared state between tests)
- Source tested libraries with relative paths from test files

## E2E Tests (`e2e/`)

E2E tests deploy a real app on a disposable k3d cluster and verify health checks.

### How It Works

1. `setup-k3d.sh` — creates a k3d cluster (`e2e-test`)
2. `run-e2e.sh` — deploys the app, runs health checks
3. `teardown-k3d.sh` — destroys the k3d cluster

`make test-e2e` wraps all three steps into a single command.

### Key Files

- `run-e2e.sh` — main harness; sources bootstrap libs, sets CI overrides
- `generate-params.sh` — auto-generates `PARAM_*` values from `app.yaml` parameters
- `fixtures/<app>.env` — per-app fixture overrides (pre-set specific `PARAM_*` values)

### Environment Overrides

`run-e2e.sh` overrides production paths so bootstrap scripts work locally:

- `MARKETPLACE_DIR` → repo root (instead of `/opt/cuemby/marketplace`)
- `LOG_DIR` → `.e2e-logs/`
- `STATE_DIR` → `.e2e-state/`
- `CI_SKIP_SSL=true` — skips cert-manager in E2E
- k3d context: `k3d-e2e-test`

### Adding Fixtures

Create `tests/e2e/fixtures/<app>.env` to pre-set parameters for a specific app:

```bash
# tests/e2e/fixtures/myapp.env
export PARAM_ADMIN_USER="e2e-admin"
export PARAM_CUSTOM_SETTING="test-value"
```

Parameters not covered by a fixture are auto-generated:

- `password` type → `TestPass1234`
- Other required params → default from `app.yaml`, or `test-<param_name>`

### CI (GitHub Actions)

The `.github/workflows/e2e.yml` workflow:

- Triggers on push to `main` (if `apps/`, `bootstrap/`, or `tests/e2e/` changed)
- Builds a matrix of `{app, version}` pairs from each changed app's `app.yaml`
- Each combination runs as an independent job: `E2E · <app> v<version>`
- Manual trigger supports specific `app` and optional `version` inputs
