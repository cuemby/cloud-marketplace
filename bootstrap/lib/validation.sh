#!/usr/bin/env bash
# validation.sh — Input and app.yaml validation functions.
# Source this file; do not execute directly.

# Validate that required environment variables are set and non-empty.
# Usage: validate_required_env VAR1 VAR2 ...
validate_required_env() {
    local missing=()
    for var in "$@"; do
        if [[ -z "${!var:-}" ]]; then
            missing+=("$var")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing[*]}"
        return 1
    fi
    return 0
}

# Validate that the named app exists in the apps directory.
# Usage: validate_app_exists <app_name>
validate_app_exists() {
    local app_name="$1"
    local app_dir="${APPS_DIR}/${app_name}"

    if [[ ! -d "$app_dir" ]]; then
        log_error "App directory not found: ${app_dir}"
        return 1
    fi

    if [[ ! -f "${app_dir}/app.yaml" ]]; then
        log_error "app.yaml not found: ${app_dir}/app.yaml"
        return 1
    fi

    return 0
}

# Validate app version against supported versions in app.yaml.
# Usage: validate_app_version <app_name> <version>
validate_app_version() {
    local app_name="$1"
    local version="$2"
    local app_yaml="${APPS_DIR}/${app_name}/app.yaml"

    if [[ -z "$version" ]]; then
        log_debug "No version specified, will use default"
        return 0
    fi

    local supported
    supported="$(yq -r '.versions[]' "$app_yaml" 2>/dev/null)"
    if [[ -z "$supported" ]]; then
        log_warn "No versions list in app.yaml, skipping version check"
        return 0
    fi

    if ! echo "$supported" | grep -qx "$version"; then
        log_error "Version '${version}' not in supported versions for ${app_name}"
        log_error "Supported: ${supported}"
        return 1
    fi

    return 0
}

# Validate PARAM_* env vars against parameters defined in app.yaml.
# Checks that required parameters are present.
# Usage: validate_parameters <app_name>
validate_parameters() {
    local app_name="$1"
    local app_yaml="${APPS_DIR}/${app_name}/app.yaml"

    local param_count
    param_count="$(yq -r '.parameters | length' "$app_yaml" 2>/dev/null)"
    if [[ "$param_count" == "0" ]] || [[ "$param_count" == "null" ]]; then
        log_debug "No parameters defined for ${app_name}"
        return 0
    fi

    local i=0
    while [[ $i -lt $param_count ]]; do
        local param_name param_required
        param_name="$(yq -r ".parameters[$i].name" "$app_yaml")"
        param_required="$(yq -r ".parameters[$i].required" "$app_yaml")"

        if [[ "$param_required" == "true" ]]; then
            local env_var="PARAM_${param_name}"
            if [[ -z "${!env_var:-}" ]]; then
                log_error "Required parameter missing: ${env_var}"
                return 1
            fi
        fi
        i=$((i + 1))
    done

    return 0
}
