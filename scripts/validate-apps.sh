#!/usr/bin/env bash
# validate-apps.sh — Validate app.yaml schema across all apps.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
APPS_DIR="${REPO_DIR}/apps"

REQUIRED_FIELDS=("name" "displayName" "description" "category" "chart" "requirements")
REQUIRED_CHART_FIELDS=("name" "repository" "version")
REQUIRED_REQ_FIELDS=("cpu" "memory" "disk")

errors=0

validate_app() {
    local app_yaml="$1"
    local app_dir
    app_dir="$(dirname "$app_yaml")"
    local app_name
    app_name="$(basename "$app_dir")"

    echo "Validating: ${app_name}"

    # Check required top-level fields
    for field in "${REQUIRED_FIELDS[@]}"; do
        local val
        val="$(yq -r ".${field}" "$app_yaml" 2>/dev/null)"
        if [[ "$val" == "null" ]] || [[ -z "$val" ]]; then
            echo "  ERROR: Missing required field: ${field}"
            errors=$((errors + 1))
        fi
    done

    # Check required chart fields
    for field in "${REQUIRED_CHART_FIELDS[@]}"; do
        local val
        val="$(yq -r ".chart.${field}" "$app_yaml" 2>/dev/null)"
        if [[ "$val" == "null" ]] || [[ -z "$val" ]]; then
            echo "  ERROR: Missing chart.${field}"
            errors=$((errors + 1))
        fi
    done

    # Check required requirements fields
    for field in "${REQUIRED_REQ_FIELDS[@]}"; do
        local val
        val="$(yq -r ".requirements.${field}" "$app_yaml" 2>/dev/null)"
        if [[ "$val" == "null" ]] || [[ -z "$val" ]]; then
            echo "  ERROR: Missing requirements.${field}"
            errors=$((errors + 1))
        fi
    done

    # Validate parameters have helmMapping
    local param_count
    param_count="$(yq -r '.parameters | length' "$app_yaml" 2>/dev/null)"
    if [[ "$param_count" != "null" ]] && [[ "$param_count" -gt 0 ]]; then
        local i=0
        while [[ $i -lt $param_count ]]; do
            local pname mapping
            pname="$(yq -r ".parameters[$i].name" "$app_yaml")"
            mapping="$(yq -r ".parameters[$i].helmMapping" "$app_yaml")"
            if [[ "$mapping" == "null" ]] || [[ -z "$mapping" ]]; then
                echo "  ERROR: Parameter '${pname}' missing helmMapping"
                errors=$((errors + 1))
            fi
            i=$((i + 1))
        done
    fi

    # Check that chart directory exists
    if [[ ! -d "${app_dir}/chart" ]]; then
        echo "  ERROR: chart/ directory missing"
        errors=$((errors + 1))
    fi

    # Check that cloud-init files exist (both YAML and bash formats)
    if [[ ! -f "${app_dir}/cloud-init.yaml" ]]; then
        echo "  ERROR: cloud-init.yaml missing"
        errors=$((errors + 1))
    fi
    if [[ ! -f "${app_dir}/cloud-init.sh" ]]; then
        echo "  ERROR: cloud-init.sh missing"
        errors=$((errors + 1))
    fi

    # Check directory name matches app.yaml name
    local yaml_name
    yaml_name="$(yq -r '.name' "$app_yaml" 2>/dev/null)"
    if [[ "$yaml_name" != "$app_name" ]]; then
        echo "  ERROR: app.yaml name '${yaml_name}' does not match directory '${app_name}'"
        errors=$((errors + 1))
    fi

    echo "  Done."
}

main() {
    echo "==> Validating all app.yaml files..."

    local app_yamls
    app_yamls="$(find "$APPS_DIR" -maxdepth 2 -name 'app.yaml' -not -path '*/_template/*' | sort)"

    if [[ -z "$app_yamls" ]]; then
        echo "No apps found."
        exit 0
    fi

    while IFS= read -r app_yaml; do
        validate_app "$app_yaml"
    done <<< "$app_yamls"

    if [[ $errors -gt 0 ]]; then
        echo ""
        echo "FAILED: ${errors} validation error(s) found."
        exit 1
    fi

    echo ""
    echo "All apps validated successfully."
}

main "$@"
