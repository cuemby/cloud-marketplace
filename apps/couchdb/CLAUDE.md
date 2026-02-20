# apps/couchdb/

Apache CouchDB NoSQL document database using the **manifest** deployment method.

## Architecture

- **Single-tier**: CouchDB only, single-node mode
- **Deployment + Recreate**: Single-node K3s VM
- **NodePort 30594**: External HTTP API + Fauxton UI access
- **Official image**: `docker.io/library/couchdb:<version>` (Apache 2.0)

## Versions

Three versions supported: 3.5.1, 3.4.3, 3.3.3.

## Parameters

All parameters use `PARAM_*` prefix at runtime. Admin password is auto-generated in `hooks/pre-install.sh` if not provided.

## Single-Node Setup

Post-install calls `PUT /_cluster_setup` with `{"action":"enable_single_node"}` to create system databases (`_users`, `_replicator`, `_global_changes`).

## Manifest Ordering

```
00-secrets.yaml              -> Admin credentials (COUCHDB_USER, COUCHDB_PASSWORD)
10-couchdb-pvc.yaml          -> Data storage
20-couchdb-deployment.yaml   -> CouchDB Deployment with probes
40-couchdb-service.yaml      -> NodePort 30594
```

## Health Checks

- `GET /_up` returns 200 when healthy
- PVC binding verification

## Networking / Firewall

The following ports must be opened at the firewall or load balancer level:

| Port | Protocol | Purpose | When |
|------|----------|---------|------|
| **30594** | TCP | HTTP API + Fauxton UI (NodePort) | Always |

## Version Update Procedure

1. Check latest release at https://couchdb.apache.org/
2. Verify Docker Hub tag exists: `docker.io/library/couchdb:<new>`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make test-e2e APP=couchdb`
