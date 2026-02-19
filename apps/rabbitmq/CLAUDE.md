# apps/rabbitmq/

Standalone RabbitMQ message broker application using the **manifest** deployment method.

## Architecture

- **Single-tier**: RabbitMQ with built-in management plugin (no separate app + DB)
- **Deployment + Recreate**: Single-node K3s VM, single replica
- **NodePort 30672**: AMQP protocol access
- **NodePort 31672**: Management UI access via `http://<VM-IP>:31672`
- **Official image**: `docker.io/library/rabbitmq:<version>-management` (MPL 2.0)

## Versions

Three version lines supported: 4.2.4 (latest, default), 4.1.8 (stable), 4.0.9 (LTS).
All use the `-management` image variant for the built-in web UI.

## Parameters

All parameters use `PARAM_*` prefix at runtime. Admin password is auto-generated in `hooks/pre-install.sh` if not provided.

## Manifest Ordering

```
00-secrets.yaml              -> Admin credentials (username, password)
05-configmap.yaml            -> rabbitmq.conf + enabled_plugins
10-pvc.yaml                  -> Storage for /var/lib/rabbitmq (local-path, RWO)
20-statefulset.yaml          -> RabbitMQ Deployment with probes
40-service.yaml              -> AMQP NodePort on 30672
41-service-management.yaml   -> Management UI NodePort on 31672
```

## Health Checks

- `rabbitmq-diagnostics -q check_running` via kubectl exec (node status)
- `rabbitmqctl list_queues` via kubectl exec (broker functionality)
- PVC binding verification

## Version Update Procedure

1. Check latest patch at https://www.rabbitmq.com/release-information
2. Verify Docker Hub tag exists: `docker.io/library/rabbitmq:<new>-management`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make test-e2e APP=rabbitmq`
