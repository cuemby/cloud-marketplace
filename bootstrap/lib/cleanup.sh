#!/usr/bin/env bash
# cleanup.sh — State tracking, error handling, and cleanup.
# Source this file; do not execute directly.

# Write state to the JSON state file.
# Includes deployMethod from app.yaml for UI consumption.
# Usage: write_state <phase> [error_message]
write_state() {
    local phase="$1"
    local error_msg="${2:-}"
    local timestamp
    timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    mkdir -p "$(dirname "$STATE_FILE")"

    # Read deployment method from app.yaml if available
    local deploy_method=""
    if [[ -n "${APP_NAME:-}" ]] && [[ -f "${APPS_DIR:-}/${APP_NAME}/app.yaml" ]]; then
        deploy_method="$(yq -r '.deployMethod // "helm"' "${APPS_DIR}/${APP_NAME}/app.yaml" 2>/dev/null || echo "")"
    fi

    local state_json
    if [[ -n "$error_msg" ]]; then
        state_json="$(jq -n \
            --arg phase "$phase" \
            --arg ts "$timestamp" \
            --arg app "${APP_NAME:-unknown}" \
            --arg ver "${APP_VERSION:-unknown}" \
            --arg method "$deploy_method" \
            --arg err "$error_msg" \
            '{phase: $phase, timestamp: $ts, app: $app, version: $ver, deployMethod: $method, error: $err}')"
    else
        state_json="$(jq -n \
            --arg phase "$phase" \
            --arg ts "$timestamp" \
            --arg app "${APP_NAME:-unknown}" \
            --arg ver "${APP_VERSION:-unknown}" \
            --arg method "$deploy_method" \
            '{phase: $phase, timestamp: $ts, app: $app, version: $ver, deployMethod: $method}')"
    fi

    echo "$state_json" > "$STATE_FILE"
    log_info "State: ${phase}"
}

# ERR trap handler. Writes error state and logs the failure.
# Usage: trap 'on_error $LINENO' ERR
on_error() {
    local line_no="${1:-unknown}"
    local script="${BASH_SOURCE[1]:-unknown}"
    local msg="Error in ${script} at line ${line_no}"
    log_error "$msg"
    write_state "$STATE_ERROR" "$msg"
}

# EXIT trap handler. Logs completion unless already in error state.
# Usage: trap 'on_exit' EXIT
on_exit() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Bootstrap exited with code ${exit_code}"
    else
        log_info "Bootstrap completed successfully"
    fi
}
