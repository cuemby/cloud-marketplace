# apps/kafka/

Apache Kafka distributed streaming platform using the **manifest** deployment method.

## Architecture

- **Single-tier**: Kafka in KRaft mode (no ZooKeeper)
- **Deployment + Recreate**: Single-node K3s VM, combined broker+controller
- **NodePort 30909**: External client/broker access
- **Official image**: `apache/kafka:<version>` (Apache 2.0)

## Versions

Three versions supported: 4.2.0, 4.1.1, 4.0.1.

## Parameters

All parameters use `PARAM_*` prefix at runtime. Cluster ID is auto-generated in `hooks/pre-install.sh` if not provided.

## KRaft Mode

Kafka runs in KRaft mode (no ZooKeeper dependency). Single node acts as both broker and controller:
- `KAFKA_PROCESS_ROLES=broker,controller`
- `KAFKA_NODE_ID=1`
- `KAFKA_CONTROLLER_QUORUM_VOTERS=1@localhost:9093`

## Manifest Ordering

```
05-configmap.yaml              -> KRaft config (process roles, listeners, cluster ID)
10-kafka-pvc.yaml              -> Data storage
20-kafka-deployment.yaml       -> Kafka Deployment with probes
40-kafka-service.yaml          -> NodePort 30909
```

## Health Checks

- TCP socket check on port 9092 (Kafka has no HTTP health endpoint)
- PVC binding verification

## Networking / Firewall

The following ports must be opened at the firewall or load balancer level:

| Port | Protocol | Purpose | When |
|------|----------|---------|------|
| **30909** | TCP | Kafka broker access (NodePort) | Always |

## Version Update Procedure

1. Check latest release at https://kafka.apache.org/downloads
2. Verify Docker Hub tag exists: `apache/kafka:<new>`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make test-e2e APP=kafka`
