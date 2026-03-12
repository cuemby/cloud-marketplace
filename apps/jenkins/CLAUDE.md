# apps/jenkins/

CI/CD automation server using the **manifest** deployment method.

## Architecture

- **Single-tier**: Jenkins only (JVM-based)
- **Deployment + Recreate**: Single-node K3s VM
- **NodePort 30080**: External HTTP access (web UI)
- **NodePort 30500**: External JNLP agent connections
- **Official image**: `jenkins/jenkins:<version>-lts-jdk21` (MIT License)

## Versions

Three LTS versions supported: 2.541.2, 2.541.1, 2.528.3 (all JDK 21).

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| JENKINS_ADMIN_PASSWORD | auto-generated | Admin password |
| JENKINS_DATA_SIZE | 20Gi | Jenkins home storage |
| JENKINS_JAVA_OPTS | -Xms512m -Xmx1g | JVM heap settings |

## Admin Account

Admin user (`admin`) is created automatically via Groovy init script.
Password is auto-generated and stored in Secret `jenkins-admin-secret`.
Setup wizard is skipped (`-Djenkins.install.runSetupWizard=false`).

## Manifest Ordering

```
00-secrets.yaml                -> Admin password (auto-generated)
05-configmap.yaml              -> JVM options (JAVA_OPTS)
06-init-groovy.yaml            -> Groovy init scripts (admin user + URL config)
10-jenkins-pvc.yaml            -> Jenkins home storage
20-jenkins-deployment.yaml     -> Jenkins Deployment with probes + init groovy mount
40-jenkins-http-service.yaml   -> NodePort 30080 (HTTP)
41-jenkins-agent-service.yaml  -> NodePort 30500 (JNLP agents)
42-jenkins-web.yaml            -> ClusterIP for HTTPS Gateway
```

## Health Checks

- HTTP GET `/login` returns 200 (works before setup wizard completion)
- PVC binding verification

## Networking / Firewall

The following ports must be opened at the firewall or load balancer level:

| Port | Protocol | Purpose | When |
|------|----------|---------|------|
| **443** | HTTPS | Web UI via Traefik Gateway | SSL enabled |
| **80** | HTTP | Redirects to HTTPS (301) | SSL enabled |
| **30080** | TCP | Web UI (NodePort) | Always |
| **30500** | TCP | JNLP agents (NodePort) | Always |

## Version Update Procedure

1. Check latest LTS at https://www.jenkins.io/changelog-stable/
2. Verify Docker Hub tag exists: `jenkins/jenkins:<new>-lts-jdk21`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make test-e2e APP=jenkins`
