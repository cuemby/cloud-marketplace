# apps/mlflow/

Open-source platform for managing the end-to-end machine learning lifecycle. **Manifest** deployment method.

## Architecture

- **2-component stack**: MLflow tracking server + PostgreSQL 17.8
- **Deployment + Recreate**: Single-node K3s VM, all components as Deployments
- **NodePort 30500**: External access via HTTP (MLflow web UI)
- **Images**: `ghcr.io/mlflow/mlflow` (Apache 2.0), `postgres:17.8-alpine` (PostgreSQL License)

## Versions

Three versions supported: 3.9.0 (default), 3.8.1, 3.7.0.

## Parameters

All parameters use `PARAM_*` prefix at runtime. Database password is auto-generated in `hooks/pre-install.sh`.

## Manifest Ordering

```
00-secrets.yaml              -> DB credentials
10-postgres-pvc.yaml         -> PostgreSQL data storage
11-mlflow-pvc.yaml           -> MLflow artifact storage
20-postgres-deployment.yaml  -> PostgreSQL 17.8
30-mlflow-deployment.yaml    -> MLflow server (with wait-for-postgres init)
40-postgres-service.yaml     -> ClusterIP for PostgreSQL
41-mlflow-service.yaml       -> NodePort 30500
```

## Health Checks

- PostgreSQL: `pg_isready -U mlflow`
- MLflow: HTTP GET `http://127.0.0.1:5000/health`
- PVC binding verification

## Access

```bash
http://<VM-IP>:30500
```

No authentication by default. MLflow tracking server is open access.

## Version Update Procedure

1. Check latest release at https://github.com/mlflow/mlflow/releases
2. Verify GHCR tag exists: `ghcr.io/mlflow/mlflow:v<new>`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make test-e2e APP=mlflow`
