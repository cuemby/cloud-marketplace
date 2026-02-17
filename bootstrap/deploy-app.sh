#!/usr/bin/env bash
# deploy-app.sh — Deploy an application via its wrapper Helm chart.
# Reads PARAM_* env vars and maps them to Helm --set flags using app.yaml helmMapping.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/constants.sh
source "${SCRIPT_DIR}/lib/constants.sh"
# shellcheck source=lib/logging.sh
source "${SCRIPT_DIR}/lib/logging.sh"
# shellcheck source=lib/retry.sh
source "${SCRIPT_DIR}/lib/retry.sh"

deploy_app() {
    local app_name="${APP_NAME:?APP_NAME is required}"
    local app_dir="${APPS_DIR}/${app_name}"
    local app_yaml="${app_dir}/app.yaml"
    local chart_dir="${app_dir}/chart"
    local namespace="${HELM_NAMESPACE_PREFIX}${app_name}"
    local release_name="$app_name"

    # Resolve chart version from app.yaml if APP_VERSION set
    local values_args=()
    values_args+=("-f" "${chart_dir}/values.yaml")

    # Use size profile if available
    local profile="${VM_PROFILE:-single}"
    local profile_values="${chart_dir}/values-${profile}.yaml"
    if [[ -f "$profile_values" ]]; then
        log_info "Using profile: ${profile}"
        values_args+=("-f" "$profile_values")
    fi

    # Build --set flags from PARAM_* env vars
    local set_args=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && set_args+=("--set" "$line")
    done < <(build_set_args "$app_yaml")

    # Run pre-install hook
    run_hook "$app_dir" "pre-install"

    # Create namespace
    log_info "Creating namespace: ${namespace}"
    kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -

    # Clean up stuck/failed releases before deploying
    cleanup_stuck_release "$release_name" "$namespace"

    # Update chart dependencies
    log_info "Updating Helm dependencies..."
    helm dependency update "$chart_dir"

    # Deploy
    log_info "Deploying ${app_name} (release: ${release_name}, namespace: ${namespace})..."
    local helm_cmd=(
        helm upgrade --install "$release_name" "$chart_dir"
        --namespace "$namespace"
        "${values_args[@]}"
        --atomic
        --wait
        --timeout "${TIMEOUT_HELM_DEPLOY}s"
    )

    # Append --set flags if any
    if [[ ${#set_args[@]} -gt 0 ]]; then
        helm_cmd+=("${set_args[@]}")
    fi

    log_debug "Helm command: ${helm_cmd[*]}"
    "${helm_cmd[@]}"

    log_info "Helm release deployed successfully."

    # Run post-install hook
    run_hook "$app_dir" "post-install"
}

# Clean up a Helm release stuck in a failed or pending state.
# This handles scenarios where a previous deploy crashed or was interrupted,
# leaving the release in a state that blocks subsequent deployments.
# Usage: cleanup_stuck_release <release_name> <namespace>
cleanup_stuck_release() {
    local release_name="$1"
    local namespace="$2"

    local status
    status="$(helm status "$release_name" --namespace "$namespace" -o json 2>/dev/null | jq -r '.info.status // empty')" || true

    if [[ -z "$status" ]]; then
        log_debug "No existing release '${release_name}' found — clean install."
        return 0
    fi

    log_info "Existing release '${release_name}' status: ${status}"

    case "$status" in
        deployed)
            log_info "Release is deployed — upgrade will proceed normally."
            ;;
        failed|pending-install|pending-upgrade|pending-rollback)
            log_warn "Release is stuck in '${status}' state — removing before redeploy."
            if helm uninstall "$release_name" --namespace "$namespace" --wait 2>/dev/null; then
                log_info "Stuck release removed successfully."
            else
                log_warn "helm uninstall returned non-zero — forcing cleanup via secret deletion."
                kubectl delete secrets -n "$namespace" -l "owner=helm,name=${release_name}" --ignore-not-found
                log_info "Helm release secrets cleaned up."
            fi
            ;;
        uninstalling)
            log_warn "Release is stuck uninstalling — cleaning up secrets directly."
            kubectl delete secrets -n "$namespace" -l "owner=helm,name=${release_name}" --ignore-not-found
            log_info "Helm release secrets cleaned up."
            ;;
        *)
            log_warn "Unexpected release status '${status}' — attempting uninstall."
            helm uninstall "$release_name" --namespace "$namespace" --wait 2>/dev/null || true
            ;;
    esac
}

# Build --set flags from PARAM_* environment variables using helmMapping.
# Outputs one helmMapping=value per line (caller adds --set).
# Usage: build_set_args <app_yaml_path>
build_set_args() {
    local app_yaml="$1"

    local param_count
    param_count="$(yq -r '.parameters | length' "$app_yaml" 2>/dev/null)"
    if [[ "$param_count" == "0" ]] || [[ "$param_count" == "null" ]]; then
        return 0
    fi

    local i=0
    while [[ $i -lt $param_count ]]; do
        local param_name helm_mapping
        param_name="$(yq -r ".parameters[$i].name" "$app_yaml")"
        helm_mapping="$(yq -r ".parameters[$i].helmMapping" "$app_yaml")"

        local env_var="PARAM_${param_name}"
        local env_val="${!env_var:-}"

        if [[ -n "$env_val" ]] && [[ "$helm_mapping" != "null" ]]; then
            log_info "Parameter: ${env_var} → ${helm_mapping}"
            echo "${helm_mapping}=${env_val}"
        fi

        i=$((i + 1))
    done
}

# Run a lifecycle hook if it exists.
# Usage: run_hook <app_dir> <hook_name>
run_hook() {
    local app_dir="$1"
    local hook_name="$2"
    local hook_script="${app_dir}/hooks/${hook_name}.sh"

    if [[ -f "$hook_script" ]]; then
        log_info "Running ${hook_name} hook..."
        bash "$hook_script"
        log_info "${hook_name} hook completed."
    else
        log_debug "No ${hook_name} hook found, skipping."
    fi
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    deploy_app
fi
