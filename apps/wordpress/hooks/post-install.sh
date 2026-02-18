#!/usr/bin/env bash
# post-install.sh — WordPress post-install hook.
# Completes the WordPress "famous 5-minute install" via HTTP POST.
# The official wordpress Docker image does NOT include WP-CLI,
# so we use curl to POST the install form from inside the pod.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}wordpress"

log_info "[wordpress/post-install] Completing WordPress installation..."

# --- Wait for WordPress pod to be ready ---
_get_wp_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=wordpress,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_wp_pod_ready() {
    local pod
    pod="$(_get_wp_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

log_info "[wordpress/post-install] Waiting for WordPress pod to be ready..."
retry_with_timeout 300 10 _wp_pod_ready

wp_pod="$(_get_wp_pod)"
log_info "[wordpress/post-install] WordPress pod ready: ${wp_pod}"

# --- Complete the install wizard via HTTP POST ---
# WordPress install form at /wp-admin/install.php?step=2 accepts:
#   weblog_title, user_name, admin_password, admin_password2, admin_email, blog_public
_complete_wp_install() {
    local admin_user="${PARAM_WORDPRESS_ADMIN_USER:-admin}"
    local admin_pass="${PARAM_WORDPRESS_ADMIN_PASSWORD}"
    local admin_email="${PARAM_WORDPRESS_ADMIN_EMAIL:-admin@example.com}"
    local site_title="${PARAM_WORDPRESS_SITE_TITLE:-My WordPress Site}"

    kubectl exec -n "${local_namespace}" "${wp_pod}" -- \
        curl -sS -o /dev/null -w '%{http_code}' \
        --max-time 30 \
        -X POST "http://localhost/wp-admin/install.php?step=2" \
        --data-urlencode "weblog_title=${site_title}" \
        --data-urlencode "user_name=${admin_user}" \
        --data-urlencode "admin_password=${admin_pass}" \
        --data-urlencode "admin_password2=${admin_pass}" \
        --data-urlencode "admin_email=${admin_email}" \
        --data-urlencode "blog_public=0" \
        -H "Host: localhost"
}

log_info "[wordpress/post-install] Running WordPress install wizard..."
install_status="$(_complete_wp_install)" || true

if [[ "$install_status" =~ ^(200|302)$ ]]; then
    log_info "[wordpress/post-install] WordPress installation completed successfully."
else
    log_warn "[wordpress/post-install] Install wizard returned HTTP ${install_status} (may already be installed)."
fi

# --- Log access info ---
local_port="${PARAM_HTTP_NODEPORT:-${DEFAULT_HTTP_NODEPORT}}"
log_info "[wordpress/post-install] Site: http://<VM-IP>:${local_port}"
log_info "[wordpress/post-install] Admin: http://<VM-IP>:${local_port}/wp-admin"
log_info "[wordpress/post-install] Username: ${PARAM_WORDPRESS_ADMIN_USER:-admin}"
