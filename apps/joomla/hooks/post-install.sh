#!/usr/bin/env bash
# post-install.sh — Joomla post-install hook.
# Waits for Joomla to be ready, updates admin password, and logs access info.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../../../bootstrap"

# shellcheck source=../../../bootstrap/lib/logging.sh
source "${BOOTSTRAP_DIR}/lib/logging.sh"
# shellcheck source=../../../bootstrap/lib/constants.sh
source "${BOOTSTRAP_DIR}/lib/constants.sh"
# shellcheck source=../../../bootstrap/lib/retry.sh
source "${BOOTSTRAP_DIR}/lib/retry.sh"

local_namespace="${HELM_NAMESPACE_PREFIX}joomla"

log_info "[joomla/post-install] Waiting for Joomla to be ready..."

# --- Wait for Joomla pod to be ready ---
_get_joomla_pod() {
    kubectl get pods -n "${local_namespace}" \
        -l app.kubernetes.io/name=joomla,app.kubernetes.io/component=app \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

_joomla_pod_ready() {
    local pod
    pod="$(_get_joomla_pod)"
    [[ -n "$pod" ]] || return 1
    local phase
    phase="$(kubectl get pod "$pod" -n "${local_namespace}" \
        -o jsonpath='{.status.phase}' 2>/dev/null)"
    [[ "$phase" == "Running" ]]
}

retry_with_timeout 300 10 _joomla_pod_ready

joomla_pod="$(_get_joomla_pod)"
log_info "[joomla/post-install] Joomla pod ready: ${joomla_pod}"

# --- Set the user's desired admin password ---
# The Docker entrypoint requires >= 12 chars, so we use a long generated
# password for auto-install, then update the DB to the user's actual password.
final_password="${PARAM_JOOMLA_ADMIN_PASSWORD_FINAL:-${PARAM_JOOMLA_ADMIN_PASSWORD:-}}"
if [[ -n "${final_password}" ]]; then
    log_info "[joomla/post-install] Setting admin password in database..."

    # Wait for auto-install to finish (configuration.php signals completion)
    for _i in $(seq 1 60); do
        if kubectl exec -n "${local_namespace}" "${joomla_pod}" -- \
            test -f /var/www/html/configuration.php 2>/dev/null; then
            break
        fi
        sleep 5
    done

    # Write a temp PHP script to the container (avoids shell escaping issues)
    # The script reads password and db credentials from environment variables
    kubectl exec -n "${local_namespace}" "${joomla_pod}" -- \
        bash -c 'cat > /tmp/update_admin_password.php' <<'PHPSCRIPT'
<?php
$password = getenv('_ADMIN_PASS');
$dbpass   = getenv('JOOMLA_DB_PASSWORD');
$dbhost   = getenv('JOOMLA_DB_HOST') ?: 'joomla-mariadb';
$dbname   = getenv('JOOMLA_DB_NAME') ?: 'joomla';
$dbuser   = getenv('JOOMLA_DB_USER') ?: 'joomla';

// Read table prefix from configuration.php
$cfg = file_get_contents('/var/www/html/configuration.php');
preg_match('/dbprefix\s*=\s*[\x27\x22](.*?)[\x27\x22]/', $cfg, $m);
$prefix = $m[1] ?? 'joomla_';

$hash = password_hash($password, PASSWORD_BCRYPT);

try {
    $pdo = new PDO("mysql:host=$dbhost;dbname=$dbname", $dbuser, $dbpass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $stmt = $pdo->prepare("UPDATE {$prefix}users SET password = ? WHERE username = ?");
    $stmt->execute([$hash, 'admin']);
    echo $stmt->rowCount() > 0 ? 'OK' : 'NO_MATCH';
} catch (Exception $e) {
    fwrite(STDERR, $e->getMessage() . "\n");
    exit(1);
}
PHPSCRIPT

    # Execute the script with the password passed as an env var
    pw_update_result=$(kubectl exec -n "${local_namespace}" "${joomla_pod}" -- \
        env "_ADMIN_PASS=${final_password}" php /tmp/update_admin_password.php 2>&1) || true

    # Clean up
    kubectl exec -n "${local_namespace}" "${joomla_pod}" -- rm -f /tmp/update_admin_password.php 2>/dev/null || true

    if [[ "${pw_update_result}" == "OK" ]]; then
        log_info "[joomla/post-install] Admin password updated successfully."
    else
        log_warn "[joomla/post-install] Could not update admin password: ${pw_update_result}"
        final_password="<check secret for auto-generated password>"
    fi
fi

# --- Log access info ---
local_port="${PARAM_HTTP_NODEPORT:-${DEFAULT_HTTP_NODEPORT}}"
if [[ "${PARAM_JOOMLA_SSL_ENABLED:-}" == "true" ]]; then
    log_info "[joomla/post-install] Site: https://${PARAM_JOOMLA_HOSTNAME:-<VM-IP>}"
    log_info "[joomla/post-install] Admin: https://${PARAM_JOOMLA_HOSTNAME:-<VM-IP>}/administrator/"
else
    log_info "[joomla/post-install] Site: http://<VM-IP>:${local_port}"
    log_info "[joomla/post-install] Admin: http://<VM-IP>:${local_port}/administrator/"
fi
log_info "[joomla/post-install] Admin user: admin"
log_info "[joomla/post-install] Admin password: ${final_password:-<check secret>}"
log_info "[joomla/post-install] Joomla auto-installs on first boot (no wizard)."
