# apps/rancher/

Complete Kubernetes management platform for deploying and managing clusters across any infrastructure. **Manifest** deployment method.

## Architecture

- **Single-component**: Rancher with embedded K3s/etcd (no external database)
- **Deployment + Recreate**: Single-node K3s VM, privileged container
- **NodePort 30443**: HTTPS (self-signed cert), **NodePort 30080**: HTTP redirect
- **Image**: `docker.io/rancher/rancher` (Apache 2.0)

## Versions

Three versions supported: 2.13.2 (default), 2.12.3, 2.11.3.

## Manifest Ordering

```
00-secrets.yaml     -> Bootstrap password
10-pvc.yaml         -> Rancher data storage
20-deployment.yaml  -> Rancher (privileged, embedded K3s)
40-service.yaml     -> NodePort 30443 (HTTPS) + 30080 (HTTP)
```

## Networking / Firewall

The following ports must be opened at the firewall or load balancer level:

| Port | Protocol | Purpose | When |
|------|----------|---------|------|
| **443** | HTTPS | Web UI via Traefik Gateway | SSL enabled |
| **80** | HTTP | Redirects to HTTPS (301) | SSL enabled |
| **30443** | TCP | HTTPS self-signed (NodePort) | Always |
| **30080** | TCP | HTTP redirect (NodePort) | Always |

## Access

```bash
# Web UI (HTTPS with self-signed cert)
https://<VM-IP>:30443

# Health check
curl -k https://localhost:30443/healthz
```
