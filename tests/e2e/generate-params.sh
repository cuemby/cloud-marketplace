#!/usr/bin/env bash
# generate-params.sh — Auto-generate test PARAM_* values from app.yaml.
# Sources per-app fixture overrides, then fills remaining required params.
#
# Usage: source this file, then call load_test_params <app_name>
# shellcheck disable=SC2034  # Variables are used by callers via export.

GENERATE_PARAMS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# load_test_params <app_name>
# Reads app.yaml, loads fixture overrides, and exports PARAM_* for all required params.
load_test_params() {
    local app_name="$1"
    local app_yaml="${APPS_DIR}/${app_name}/app.yaml"
    local fixture_file="${GENERATE_PARAMS_DIR}/fixtures/${app_name}.env"

    # Load per-app fixture overrides first (can pre-set specific PARAM_* vars)
    if [[ -f "$fixture_file" ]]; then
        # shellcheck disable=SC1090
        source "$fixture_file"
    fi

    local param_count
    param_count="$(yq -r '.parameters | length' "$app_yaml" 2>/dev/null)"
    if [[ "$param_count" == "0" ]] || [[ "$param_count" == "null" ]]; then
        return 0
    fi

    local i=0
    while [[ $i -lt $param_count ]]; do
        local name required param_type default_val
        name="$(yq -r ".parameters[$i].name" "$app_yaml")"
        required="$(yq -r ".parameters[$i].required" "$app_yaml")"
        param_type="$(yq -r ".parameters[$i].type // \"string\"" "$app_yaml")"
        default_val="$(yq -r ".parameters[$i].default // \"\"" "$app_yaml")"

        local env_var="PARAM_${name}"

        # Skip if already set (fixture or environment)
        if [[ -n "${!env_var:-}" ]]; then
            i=$((i + 1))
            continue
        fi

        # Auto-generate values for required params only
        if [[ "$required" == "true" ]]; then
            case "$param_type" in
                password)
                    export "$env_var=TestP@ss123!"
                    ;;
                *)
                    if [[ -n "$default_val" ]]; then
                        export "$env_var=$default_val"
                    else
                        local lower_name
                        lower_name="$(echo "$name" | tr '[:upper:]' '[:lower:]')"
                        export "$env_var=test-${lower_name}"
                    fi
                    ;;
            esac
        fi

        i=$((i + 1))
    done
}
