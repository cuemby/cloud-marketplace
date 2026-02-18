# apps/cassandra/

Standalone Apache Cassandra NoSQL database using the **manifest** deployment method.

## Architecture

- **Single-tier**: Cassandra is the application itself (single-node mode)
- **Deployment + Recreate**: Single-node K3s VM, no StatefulSet needed
- **NodePort 30942**: External CQL access via `cqlsh <VM-IP> 30942`
- **Official image**: `docker.io/library/cassandra:<version>` (Apache 2.0)
- **JVM-based**: Requires 4 CPU / 8GB RAM minimum (larger than PostgreSQL)

## Versions

Three latest version lines: 5.0.6, 4.1.10, 4.0.19 (Debian Bookworm base).

## Parameters

All parameters use `PARAM_*` prefix at runtime. The superuser password is auto-generated in `hooks/pre-install.sh` and applied via CQL in `hooks/post-install.sh` (the official Docker image does not support password env vars — that's Bitnami-specific).

## JVM Tuning

Heap is configured via `MAX_HEAP_SIZE` and `HEAP_NEWSIZE` env vars (read by `cassandra-env.sh` in the official image). These must be set as a pair. Default: 2G max heap + 512M young gen (~25% of 8GB VM RAM).

## Single-Node Configuration

- `CASSANDRA_SEEDS` is NOT set (official image auto-detects pod IP; setting it to a Service name causes bootstrap loops)
- `CASSANDRA_ENDPOINT_SNITCH=SimpleSnitch` (no DC topology)
- `CASSANDRA_NUM_TOKENS=256` (standard vnode count)
- Replication: use `SimpleStrategy` with `replication_factor: 1`

## Manifest Ordering

```text
00-secrets.yaml              -> Credentials (password for post-install CQL)
05-configmap.yaml            -> Cluster config + JVM heap tuning
10-cassandra-pvc.yaml        -> Storage for /var/lib/cassandra (local-path, RWO)
20-cassandra-deployment.yaml -> Cassandra Deployment with probes
40-cassandra-service.yaml    -> NodePort service on 30942 (CQL)
```

## Health Checks

- `nodetool status | grep "^UN"` via kubectl exec (node Up/Normal)
- `cqlsh -e "SELECT cluster_name FROM system.local"` (CQL query)
- PVC binding verification

## Authentication

The official image starts with `AllowAllAuthenticator` by default. The post-install hook sets the superuser password via `ALTER USER cassandra WITH PASSWORD '...'`. For production, users should enable `PasswordAuthenticator` in `cassandra.yaml`.

## Version Update Procedure

1. Check latest patch at https://cassandra.apache.org/_/download.html
2. Verify Docker Hub tag exists: `docker.io/library/cassandra:<new>`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make test-e2e APP=cassandra`
