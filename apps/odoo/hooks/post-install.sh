#!/usr/bin/env bash
# post-install.sh — Odoo post-install hook.
# Waits for the Odoo pod to be ready and logs access information.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}odoo"

log_info "[odoo/post-install] Waiting for Odoo to be ready..."

# --- Wait for Odoo pod to be ready ---
_get_odoo_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=odoo,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_odoo_pod_ready() {
    local pod
    pod="$(_get_odoo_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _odoo_pod_ready

odoo_pod="$(_get_odoo_pod)"
log_info "[odoo/post-install] Odoo pod ready: ${odoo_pod}"

# --- Initialize database (first deploy only) ---
_odoo_db_initialized() {
    kubectl exec -n "${local_namespace}" "${odoo_pod}" -c odoo -- \
        python3 -c "
import psycopg2
conn = psycopg2.connect(host='odoo-postgres', port=5432, user='odoo', password='${PARAM_ODOO_DB_PASSWORD}', dbname='odoo')
cur = conn.cursor()
cur.execute(\"SELECT 1 FROM information_schema.tables WHERE table_name='ir_module_module'\")
print('yes' if cur.fetchone() else 'no')
conn.close()
" 2>/dev/null
}

db_status="$(_odoo_db_initialized || echo "no")"
if [[ "$db_status" != *"yes"* ]]; then
    log_info "[odoo/post-install] Database not initialized — running 'odoo --init base'..."
    kubectl exec -n "${local_namespace}" "${odoo_pod}" -c odoo -- \
        odoo --init base --database odoo \
        --db_host odoo-postgres --db_port 5432 \
        --db_user odoo --db_password "${PARAM_ODOO_DB_PASSWORD}" \
        --stop-after-init --no-http 2>&1 | tail -5
    # Set admin login password to PARAM_ODOO_ADMIN_PASSWORD
    log_info "[odoo/post-install] Setting admin login password..."
    kubectl exec -n "${local_namespace}" "${odoo_pod}" -c odoo -- \
        python3 -c "
import psycopg2
from passlib.context import CryptContext
ctx = CryptContext(schemes=['pbkdf2_sha512'])
hashed = ctx.hash('${PARAM_ODOO_ADMIN_PASSWORD}')
conn = psycopg2.connect(host='odoo-postgres', port=5432, user='odoo', password='${PARAM_ODOO_DB_PASSWORD}', dbname='odoo')
cur = conn.cursor()
cur.execute('UPDATE res_users SET password=%s WHERE login=%s', (hashed, 'admin'))
conn.commit()
conn.close()
" 2>/dev/null
    log_info "[odoo/post-install] Admin password set."

    log_info "[odoo/post-install] Database initialized. Restarting deployment..."
    kubectl rollout restart deployment/odoo -n "${local_namespace}"
    kubectl rollout status deployment/odoo -n "${local_namespace}" --timeout=120s
else
    log_info "[odoo/post-install] Database already initialized, skipping."
fi

# --- Log access info ---
local_port="${PARAM_ODOO_NODEPORT:-30069}"
log_info "[odoo/post-install] Odoo web UI: http://<VM-IP>:${local_port}"
log_info "[odoo/post-install] Login: admin / <PARAM_ODOO_ADMIN_PASSWORD>"
