#!/usr/bin/env bash
# validate-apps.sh — Validate app.yaml schema across all apps.
# Supports helm, kustomize, and manifest deployment methods.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
APPS_DIR="${REPO_DIR}/apps"

REQUIRED_FIELDS=("name" "displayName" "description" "category" "requirements")
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

    # Check required top-level fields (shared across all deploy methods)
    for field in "${REQUIRED_FIELDS[@]}"; do
        local val
        val="$(yq -r ".${field}" "$app_yaml" 2>/dev/null)"
        if [[ "$val" == "null" ]] || [[ -z "$val" ]]; then
            echo "  ERROR: Missing required field: ${field}"
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

    # Determine deployment method (default: helm)
    local deploy_method
    deploy_method="$(yq -r '.deployMethod // "helm"' "$app_yaml" 2>/dev/null)"

    # Method-specific validation
    case "$deploy_method" in
        helm)
            validate_helm_app "$app_yaml" "$app_dir"
            ;;
        kustomize)
            validate_kustomize_app "$app_yaml" "$app_dir"
            ;;
        manifest)
            validate_manifest_app "$app_yaml" "$app_dir"
            ;;
        *)
            echo "  ERROR: Unknown deployMethod: ${deploy_method}"
            errors=$((errors + 1))
            ;;
    esac

    # Validate versions array if present
    validate_versions "$app_yaml" "$deploy_method"

    # Check that cloud-init files exist (all deploy methods)
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

validate_helm_app() {
    local app_yaml="$1"
    local app_dir="$2"

    # Check required chart fields
    for field in "${REQUIRED_CHART_FIELDS[@]}"; do
        local val
        val="$(yq -r ".chart.${field}" "$app_yaml" 2>/dev/null)"
        if [[ "$val" == "null" ]] || [[ -z "$val" ]]; then
            echo "  ERROR: Missing chart.${field}"
            errors=$((errors + 1))
        fi
    done

    # Check that chart directory exists
    if [[ ! -d "${app_dir}/chart" ]]; then
        echo "  ERROR: chart/ directory missing"
        errors=$((errors + 1))
    fi

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
}

validate_kustomize_app() {
    local app_yaml="$1"
    local app_dir="$2"

    local base_path
    base_path="$(yq -r '.kustomize.basePath // "kustomize/base"' "$app_yaml" 2>/dev/null)"

    if [[ ! -d "${app_dir}/${base_path}" ]]; then
        echo "  ERROR: kustomize base directory '${base_path}' missing"
        errors=$((errors + 1))
    fi
}

validate_manifest_app() {
    local app_yaml="$1"
    local app_dir="$2"

    local manifests_path
    manifests_path="$(yq -r '.manifests.path // "manifests/"' "$app_yaml" 2>/dev/null)"

    if [[ ! -d "${app_dir}/${manifests_path}" ]]; then
        echo "  ERROR: manifests directory '${manifests_path}' missing"
        errors=$((errors + 1))
    fi
}

validate_versions() {
    local app_yaml="$1"
    local deploy_method="$2"

    local ver_count
    ver_count="$(yq -r '.versions | length' "$app_yaml" 2>/dev/null)"
    if [[ "$ver_count" == "null" ]] || [[ "$ver_count" -eq 0 ]]; then
        return 0
    fi

    # Check if new-style (objects) or old-style (strings)
    local first_type
    first_type="$(yq -r '.versions[0] | type' "$app_yaml" 2>/dev/null)"
    if [[ "$first_type" != "!!map" ]]; then
        return 0
    fi

    # New-style versionMap validation
    local has_default=false
    local v=0
    while [[ $v -lt $ver_count ]]; do
        local app_ver
        app_ver="$(yq -r ".versions[$v].appVersion" "$app_yaml")"
        if [[ "$app_ver" == "null" ]] || [[ -z "$app_ver" ]]; then
            echo "  ERROR: versions[$v] missing appVersion"
            errors=$((errors + 1))
        fi

        # Check method-specific version field
        if [[ "$deploy_method" == "helm" ]]; then
            local cv
            cv="$(yq -r ".versions[$v].chartVersion" "$app_yaml")"
            if [[ "$cv" == "null" ]] || [[ -z "$cv" ]]; then
                echo "  ERROR: versions[$v] missing chartVersion (required for helm)"
                errors=$((errors + 1))
            fi
        else
            local it
            it="$(yq -r ".versions[$v].imageTag" "$app_yaml")"
            if [[ "$it" == "null" ]] || [[ -z "$it" ]]; then
                echo "  ERROR: versions[$v] missing imageTag (required for ${deploy_method})"
                errors=$((errors + 1))
            fi
        fi

        local def
        def="$(yq -r ".versions[$v].default" "$app_yaml")"
        if [[ "$def" == "true" ]]; then
            has_default=true
        fi

        v=$((v + 1))
    done

    if [[ "$has_default" == "false" ]]; then
        echo "  WARN: No default version specified; first entry will be used"
    fi
}

main() {
    echo "==> Validating all app.yaml files..."

    local app_yamls
    app_yamls="$(find "$APPS_DIR" -maxdepth 2 -name 'app.yaml' -not -path '*/_template*' | sort)"

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
