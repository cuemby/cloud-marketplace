# apps/selenium/

Browser automation infrastructure for running automated tests across multiple browsers in parallel. **Manifest** deployment method.

## Architecture

- **3-component stack**: Selenium Hub + Chrome Node + Firefox Node
- **Stateless**: No PVCs or secrets — all components are ephemeral
- **NodePort 30444**: Hub (WebDriver + Grid UI)
- **Images**: `docker.io/selenium/hub`, `docker.io/selenium/node-chrome`, `docker.io/selenium/node-firefox` (Apache 2.0)

## Versions

Three versions supported: 4.40.0 (default), 4.39.0, 4.38.0.

## Parameters

All parameters use `PARAM_*` prefix at runtime. No credentials needed — Selenium Grid has no built-in auth.

## Manifest Ordering

```
20-hub-deployment.yaml     -> Selenium Hub (grid coordinator)
30-chrome-deployment.yaml  -> Chrome Node (connects to Hub)
31-firefox-deployment.yaml -> Firefox Node (connects to Hub)
40-hub-service.yaml        -> NodePort 30444 (Hub API + Grid UI)
41-chrome-service.yaml     -> ClusterIP (internal, event bus)
42-firefox-service.yaml    -> ClusterIP (internal, event bus)
```

## Health Checks

- Hub: `curl http://localhost:4444/wd/hub/status` (check `"ready": true`)
- Chrome Node: TCP check on port 5555
- Firefox Node: TCP check on port 5555

## Access

```bash
# Grid UI (visual dashboard)
curl http://<VM-IP>:30444/ui

# Grid Status (JSON API)
curl http://<VM-IP>:30444/wd/hub/status

# WebDriver endpoint (for test automation)
# http://<VM-IP>:30444/wd/hub
```

## Version Update Procedure

1. Check latest release at https://github.com/SeleniumHQ/docker-selenium/releases
2. Verify Docker Hub tags exist: `selenium/hub:<tag>`, `selenium/node-chrome:<tag>`, `selenium/node-firefox:<tag>`
3. Update `versions[]` in `app.yaml`
4. Run `make validate && make test-e2e APP=selenium`
