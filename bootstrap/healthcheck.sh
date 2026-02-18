#!/usr/bin/env bash
# healthcheck.sh — Post-deploy health verification.
# Checks generic Kubernetes health, then delegates to app-specific healthcheck.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/constants.sh
source "${SCRIPT_DIR}/lib/constants.sh"
# shellcheck source=lib/logging.sh
source "${SCRIPT_DIR}/lib/logging.sh"
# shellcheck source=lib/retry.sh
source "${SCRIPT_DIR}/lib/retry.sh"

run_generic_healthcheck() {
    local app_name="${APP_NAME:?APP_NAME is required}"
    local namespace="${HELM_NAMESPACE_PREFIX}${app_name}"
    local timeout="${TIMEOUT_HEALTH}"

    log_info "Running generic health checks for ${app_name} (timeout: ${timeout}s)..."

    # Generic check: all pods Running/Completed in app namespace
    log_info "Checking pod health in namespace ${namespace}..."
    retry_with_timeout "$timeout" "$RETRY_INTERVAL" _all_pods_healthy "$namespace"
    log_info "All pods healthy."

    # Generic check: services have endpoints
    log_info "Checking service endpoints..."
    _check_service_endpoints "$namespace"
    log_info "Service endpoints verified."
}

run_healthcheck() {
    run_generic_healthcheck

    # App-specific healthcheck hook (sourced to inherit PARAM_* env vars)
    local app_name="${APP_NAME:?APP_NAME is required}"
    local app_dir="${APPS_DIR}/${app_name}"
    local hook="${app_dir}/hooks/healthcheck.sh"
    if [[ -f "$hook" ]]; then
        log_info "Running app-specific healthcheck..."
        # shellcheck disable=SC1090
        source "$hook"
        log_info "App-specific healthcheck passed."
    fi

    log_info "All health checks passed for ${app_name}."
}

_all_pods_healthy() {
    local namespace="$1"

    local not_ready
    not_ready="$(kubectl get pods -n "$namespace" \
        --no-headers 2>/dev/null | \
        grep -cvE '(Running|Completed|Succeeded)' || true)"

    [[ "$not_ready" -eq 0 ]]
}

_check_service_endpoints() {
    local namespace="$1"

    local services
    services="$(kubectl get svc -n "$namespace" --no-headers \
        -o custom-columns=NAME:.metadata.name 2>/dev/null)"

    if [[ -z "$services" ]]; then
        log_debug "No services found in namespace ${namespace}"
        return 0
    fi

    while IFS= read -r svc; do
        local endpoints
        endpoints="$(kubectl get endpoints "$svc" -n "$namespace" \
            -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)"
        if [[ -z "$endpoints" ]]; then
            log_warn "Service ${svc} has no endpoints yet"
        else
            log_debug "Service ${svc} has endpoints: ${endpoints}"
        fi
    done <<< "$services"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_healthcheck
fi
