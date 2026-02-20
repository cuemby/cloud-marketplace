# apps/opensearch/

OpenSearch search and analytics engine using the **manifest** deployment method.

## Architecture

- **Single-tier**: OpenSearch only, single-node mode
- **Deployment + Recreate**: Single-node K3s VM
- **NodePort 30920**: External REST API access
- **Official image**: `opensearchproject/opensearch:<version>` (Apache 2.0)

## Versions

Three versions supported: 3.0.0, 2.19.1, 1.3.20.

## Parameters

All parameters use `PARAM_*` prefix at runtime. Admin password is auto-generated in `hooks/pre-install.sh` if not provided. JVM heap is configurable via `OPENSEARCH_JAVA_OPTS`.

## Security Plugin

Security plugin is **disabled** (`plugins.security.disabled=true`) for simplicity. Without this, OpenSearch requires TLS certificates even for single-node. The admin password is still stored for when users enable security later.

## JVM Tuning

Default heap: `-Xms2g -Xmx2g` (paired, ~25% of 8GB VM). Same pattern as Cassandra.

## Init Container

Requires `vm.max_map_count=262144` sysctl — set via privileged initContainer.

## Manifest Ordering

```
00-secrets.yaml              -> Admin password (OPENSEARCH_INITIAL_ADMIN_PASSWORD)
05-configmap.yaml            -> discovery.type, cluster.name, security disable, JVM opts
10-opensearch-pvc.yaml       -> Data storage
20-opensearch-deployment.yaml -> OpenSearch Deployment with probes + sysctl init
40-opensearch-service.yaml   -> NodePort 30920
```

## Health Checks

- `GET /_cluster/health` returns cluster status
- PVC binding verification

## Networking / Firewall

The following ports must be opened at the firewall or load balancer level:

| Port | Protocol | Purpose | When |
|------|----------|---------|------|
| **443** | HTTPS | REST API via Traefik Gateway | SSL enabled |
| **80** | HTTP | Redirects to HTTPS (301) | SSL enabled |
| **30920** | TCP | REST API (NodePort) | Always |

## Version Update Procedure

1. Check latest release at https://github.com/opensearch-project/OpenSearch/releases
2. Verify Docker Hub tag exists: `opensearchproject/opensearch:<new>`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make test-e2e APP=opensearch`
