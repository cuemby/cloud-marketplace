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

All parameters use `PARAM_*` prefix at runtime. No passwords to auto-generate — Jenkins creates an initial admin password at first boot.

## Admin Account

Jenkins creates an initial admin password at `/var/jenkins_home/secrets/initialAdminPassword` on first startup. The post-install hook reads and logs this password. The admin completes setup via the first-visit wizard at `http://<VM-IP>:30080`.

## Manifest Ordering

```
05-configmap.yaml              -> JVM options (JAVA_OPTS)
10-jenkins-pvc.yaml            -> Jenkins home storage
20-jenkins-deployment.yaml     -> Jenkins Deployment with probes
40-jenkins-http-service.yaml   -> NodePort 30080 (HTTP)
41-jenkins-agent-service.yaml  -> NodePort 30500 (JNLP agents)
```

## Health Checks

- HTTP GET `/login` returns 200 (works before setup wizard completion)
- PVC binding verification

## Version Update Procedure

1. Check latest LTS at https://www.jenkins.io/changelog-stable/
2. Verify Docker Hub tag exists: `jenkins/jenkins:<new>-lts-jdk21`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make test-e2e APP=jenkins`
