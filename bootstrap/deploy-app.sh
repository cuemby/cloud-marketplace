#!/usr/bin/env bash
# deploy-app.sh — Deploy an application via its declared deployment method.
# Dispatches to helm, kustomize, or manifest deployer based on app.yaml deployMethod.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/constants.sh
source "${SCRIPT_DIR}/lib/constants.sh"
# shellcheck source=lib/logging.sh
source "${SCRIPT_DIR}/lib/logging.sh"
# shellcheck source=lib/retry.sh
source "${SCRIPT_DIR}/lib/retry.sh"
# shellcheck source=lib/deploy-helpers.sh
source "${SCRIPT_DIR}/lib/deploy-helpers.sh"

# Source deployer strategies
# shellcheck source=deploy-helm.sh
source "${SCRIPT_DIR}/deploy-helm.sh"
# shellcheck source=deploy-kustomize.sh
source "${SCRIPT_DIR}/deploy-kustomize.sh"
# shellcheck source=deploy-manifest.sh
source "${SCRIPT_DIR}/deploy-manifest.sh"

deploy_app() {
    local app_name="${APP_NAME:?APP_NAME is required}"
    local app_dir="${APPS_DIR}/${app_name}"
    local app_yaml="${app_dir}/app.yaml"
    local namespace="${HELM_NAMESPACE_PREFIX}${app_name}"

    # Determine deployment method (default: helm for backward compatibility)
    local deploy_method
    deploy_method="$(yq -r '.deployMethod // "helm"' "$app_yaml")"
    log_info "Deploy method: ${deploy_method}"

    # Create namespace (shared across all methods)
    log_info "Creating namespace: ${namespace}"
    kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -

    # Run pre-install hook (shared — may export PARAM_* vars)
    run_hook "$app_dir" "pre-install"

    # Dispatch to deployer
    case "$deploy_method" in
        helm)
            deploy_helm "$app_name" "$app_dir" "$app_yaml" "$namespace"
            ;;
        kustomize)
            deploy_kustomize "$app_name" "$app_dir" "$app_yaml" "$namespace"
            ;;
        manifest)
            deploy_manifest "$app_name" "$app_dir" "$app_yaml" "$namespace"
            ;;
        *)
            log_fatal "Unknown deployment method: ${deploy_method}"
            ;;
    esac

    # Run post-install hook (shared)
    run_hook "$app_dir" "post-install"
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
# Hooks are sourced (not subshelled) so they can export PARAM_* variables.
# Usage: run_hook <app_dir> <hook_name>
run_hook() {
    local app_dir="$1"
    local hook_name="$2"
    local hook_script="${app_dir}/hooks/${hook_name}.sh"

    if [[ -f "$hook_script" ]]; then
        log_info "Running ${hook_name} hook..."
        # shellcheck disable=SC1090
        source "$hook_script"
        log_info "${hook_name} hook completed."
    else
        log_debug "No ${hook_name} hook found, skipping."
    fi
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    deploy_app
fi
