# apps/mongodb/

Standalone MongoDB database application using the **manifest** deployment method.

## Architecture

- **Single-tier**: MongoDB is the application itself (no separate app + DB)
- **Deployment + Recreate**: Single-node K3s VM, single replica
- **NodePort 30017**: External MongoDB protocol access via `mongosh mongodb://<user>:<pass>@<VM-IP>:30017/admin`
- **Official image**: `docker.io/library/mongo:<version>` (SSPL)

## Versions

Three version lines supported: 8.0.19 (latest, default), 7.0.30 (LTS), 6.0.27 (LTS).

## Parameters

All parameters use `PARAM_*` prefix at runtime. Root password is auto-generated in `hooks/pre-install.sh` if not provided. Root username defaults to `admin`.

## Manifest Ordering

```
00-secrets.yaml       -> Credentials (root username, root password)
10-pvc.yaml           -> Storage for /data/db (local-path, RWO)
20-statefulset.yaml   -> MongoDB Deployment with probes
40-service.yaml       -> NodePort service on 30017
```

## Health Checks

- `mongosh --eval "db.adminCommand('ping')"` via kubectl exec (connectivity)
- `db.getSiblingDB('test').healthcheck.insertOne(...)` via kubectl exec (write operation)
- PVC binding verification

## Networking / Firewall

The following ports must be opened at the firewall or load balancer level:

| Port | Protocol | Purpose | When |
|------|----------|---------|------|
| **30017** | TCP | MongoDB protocol access (NodePort) | Always |

## Version Update Procedure

1. Check latest patch at https://www.mongodb.com/try/download/community
2. Verify Docker Hub tag exists: `docker.io/library/mongo:<new>`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make test-e2e APP=mongodb`
