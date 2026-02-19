# apps/rancher/

Complete Kubernetes management platform for deploying and managing clusters across any infrastructure. **Manifest** deployment method.

## Architecture

- **Single-component**: Rancher with embedded K3s/etcd (no external database)
- **Deployment + Recreate**: Single-node K3s VM, privileged container
- **NodePort 30443**: HTTPS (self-signed cert), **NodePort 30080**: HTTP redirect
- **Image**: `docker.io/rancher/rancher` (Apache 2.0)

## Versions

Three versions supported: 2.13.2 (default), 2.12.3, 2.11.8.

## Manifest Ordering

```
00-secrets.yaml     -> Bootstrap password
10-pvc.yaml         -> Rancher data storage
20-deployment.yaml  -> Rancher (privileged, embedded K3s)
40-service.yaml     -> NodePort 30443 (HTTPS) + 30080 (HTTP)
```

## Access

```bash
# Web UI (HTTPS with self-signed cert)
https://<VM-IP>:30443

# Health check
curl -k https://localhost:30443/healthz
```
