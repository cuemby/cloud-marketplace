#!/usr/bin/env bash
# deploy-helm.sh — Helm deployment strategy.
# Deploys an application via its wrapper Helm chart with version resolution.
# Source this file; do not execute directly.

# Deploy an application using Helm.
# Usage: deploy_helm <app_name> <app_dir> <app_yaml> <namespace>
deploy_helm() {
    local app_name="$1"
    local app_dir="$2"
    local app_yaml="$3"
    local namespace="$4"
    local chart_dir="${app_dir}/chart"
    local release_name="$app_name"

    # Resolve chart version from APP_VERSION
    local chart_version
    chart_version="$(resolve_chart_version "$app_yaml" "${APP_VERSION:-}")"
    log_info "Chart version resolved: ${chart_version}"

    # Override dependency version in Chart.yaml before pulling deps.
    # Safe on single-use VMs — the file is never reused.
    log_info "Setting dependency version to ${chart_version}..."
    yq -i ".dependencies[0].version = \"${chart_version}\"" "${chart_dir}/Chart.yaml"

    # Build values file list
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

    # Clean up stuck/failed releases before deploying
    cleanup_stuck_release "$release_name" "$namespace"

    # Update chart dependencies
    log_info "Updating Helm dependencies..."
    helm dependency update "$chart_dir"

    # Deploy
    log_info "Deploying ${app_name} via Helm (release: ${release_name}, namespace: ${namespace})..."
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
}

# Resolve APP_VERSION (user-facing) to a Helm chart dependency version.
# Falls back to chart.version if no versionMap or APP_VERSION is empty.
# Usage: resolve_chart_version <app_yaml> <app_version>
resolve_chart_version() {
    local app_yaml="$1"
    local requested_version="$2"

    local version_count
    version_count="$(yq -r '.versions | length' "$app_yaml" 2>/dev/null)"

    if [[ "$version_count" == "0" ]] || [[ "$version_count" == "null" ]]; then
        # No versions at all — use chart.version
        yq -r '.chart.version' "$app_yaml"
        return 0
    fi

    # Check if versions entries are objects (new-style) or strings (old-style)
    local first_type
    first_type="$(yq -r '.versions[0] | type' "$app_yaml" 2>/dev/null)"

    if [[ "$first_type" != "!!map" ]]; then
        # Old-style flat string array — fall back to chart.version
        yq -r '.chart.version' "$app_yaml"
        return 0
    fi

    # New-style versionMap: look up by appVersion
    if [[ -n "$requested_version" ]]; then
        local found
        found="$(yq -r ".versions[] | select(.appVersion == \"${requested_version}\") | .chartVersion" "$app_yaml" 2>/dev/null)"
        if [[ -n "$found" ]] && [[ "$found" != "null" ]]; then
            echo "$found"
            return 0
        fi
        log_warn "Requested version '${requested_version}' not found in versions, using default."
    fi

    # Use the default entry, or fall back to first
    local default_version
    default_version="$(yq -r '.versions[] | select(.default == true) | .chartVersion' "$app_yaml" 2>/dev/null)"
    if [[ -n "$default_version" ]] && [[ "$default_version" != "null" ]]; then
        echo "$default_version"
    else
        yq -r '.versions[0].chartVersion' "$app_yaml"
    fi
}

# Clean up a Helm release stuck in a failed or pending state.
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
