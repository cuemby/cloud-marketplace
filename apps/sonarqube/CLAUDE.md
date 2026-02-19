# apps/sonarqube/

Code quality and security analysis platform supporting 30+ programming languages. **Manifest** deployment method.

## Architecture

- **2-component stack**: SonarQube Community + PostgreSQL 17.8
- **Deployment + Recreate**: Single-node K3s VM, all components as Deployments
- **NodePort 30900**: External access via SonarQube web UI
- **Images**: `docker.io/library/sonarqube` (LGPLv3 Community), `postgres:17.8-alpine` (PostgreSQL License)

## Versions

Three versions supported: 26.2.0.119303 (default), 26.1.0.118079, 25.12.0.117093.

## Parameters

All parameters use `PARAM_*` prefix at runtime. Database password is auto-generated in `hooks/pre-install.sh`.

## Manifest Ordering

```
00-secrets.yaml                -> PostgreSQL credentials
10-postgres-pvc.yaml           -> PostgreSQL data storage
11-sonarqube-pvc.yaml          -> SonarQube data + extensions
20-postgres-deployment.yaml    -> PostgreSQL 17.8
30-sonarqube-deployment.yaml   -> SonarQube app (with wait-for-postgres init)
40-postgres-service.yaml       -> ClusterIP for PostgreSQL
41-sonarqube-service.yaml      -> NodePort 30900
```

## Kernel Tuning

SonarQube requires elevated kernel settings for its embedded Elasticsearch:
- `vm.max_map_count=524288`
- `fs.file-max=131072`

These are set via cloud-init in `/etc/sysctl.d/99-sonarqube.conf` before K3s starts.

## Health Checks

- PostgreSQL: `pg_isready -U sonarqube`
- SonarQube: `curl http://localhost:9000/api/system/status` (check `"status":"UP"`)
- PVC binding verification

## Access

```bash
# Web UI
http://<VM-IP>:30900

# Default credentials (change on first login)
Username: admin
Password: admin
```

## Version Update Procedure

1. Check latest release at https://www.sonarsource.com/products/sonarqube/downloads/
2. Verify Docker Hub tag exists: `docker.io/library/sonarqube:<version>-community`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make test-e2e APP=sonarqube`
