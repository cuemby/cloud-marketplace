#!/usr/bin/env bash
# post-install.sh — HAProxy post-install hook.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}haproxy"

log_info "[haproxy/post-install] Waiting for HAProxy to be ready..."

_get_haproxy_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=haproxy,app.kubernetes.io/component=proxy \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_haproxy_pod_ready() {
    local pod
    pod="$(_get_haproxy_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _haproxy_pod_ready

haproxy_pod="$(_get_haproxy_pod)"
log_info "[haproxy/post-install] HAProxy pod ready: ${haproxy_pod}"

local_http_port="${PARAM_HAPROXY_HTTP_NODEPORT:-30080}"
local_stats_port="${PARAM_HAPROXY_STATS_NODEPORT:-30936}"
log_info "[haproxy/post-install] HTTP Frontend: http://<VM-IP>:${local_http_port}"
log_info "[haproxy/post-install] Stats Dashboard: http://<VM-IP>:${local_stats_port}/stats"
log_info "[haproxy/post-install] Stats credentials: ${PARAM_HAPROXY_STATS_USER:-admin} / <see secret>"

if [[ "${PARAM_HAPROXY_SSL_ENABLED:-}" == "true" ]]; then
    log_info "[haproxy/post-install] HTTPS Frontend: https://${PARAM_HAPROXY_HOSTNAME:-}"
    log_info "[haproxy/post-install] HTTPS Stats: https://${PARAM_HAPROXY_HOSTNAME:-}/stats"
fi

log_info "[haproxy/post-install] Demo backends (web1/web2/web3) deployed for load-balancing demo."
log_info "[haproxy/post-install] To remove demo and configure real backends:"
log_info "[haproxy/post-install]   kubectl -n ${local_namespace} delete deploy,svc,configmap -l app.kubernetes.io/component=demo"
log_info "[haproxy/post-install]   Then edit ConfigMap 'haproxy-config' with your real backend servers."
