# apps/neo4j/

Standalone Neo4j Community Edition graph database using the **manifest** deployment method.

## Architecture

- Single-tier (no separate app + DB)
- Deployment + Recreate strategy
- HTTP NodePort 30474, Bolt NodePort 30687
- Official image: docker.io/library/neo4j (Community Edition)

## Versions

Two version lines: 2026.01.4 (default, CalVer), 5.26.21 (LTS)

## Parameters

All use `PARAM_*` prefix. Password auto-generated if not provided.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `NEO4J_AUTH_PASSWORD` | (generated) | Authentication password |
| `NEO4J_DATA_SIZE` | `10Gi` | Graph data volume size |
| `NEO4J_HEAP_SIZE` | `1G` | JVM heap size |

## Manifest Ordering

00-secrets → 10-pvc → 20-statefulset → 40-service (HTTP) → 41-service-bolt (Bolt)

## Authentication

Neo4j uses `NEO4J_AUTH` env var in `neo4j/<password>` format, stored as a Kubernetes Secret.
The password is injected via `valueFrom.secretKeyRef` (not `envFrom`).

## Health Checks

- HTTP GET to `/` on port 7474 (probes)
- Cypher query via `cypher-shell` (healthcheck hook)
- PVC binding verification

## Version Update Procedure

1. Check latest patch on Docker Hub (`neo4j` official image)
2. Verify `-community` tag variant exists
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make test-e2e APP=neo4j`
