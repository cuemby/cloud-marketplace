#!/usr/bin/env bash
# new-app.sh — Scaffold a new application from a template.
# Usage: ./scripts/new-app.sh <app-name> [--method helm|kustomize|manifest]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
APPS_DIR="${REPO_DIR}/apps"

main() {
    local app_name=""
    local method="helm"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --method)
                method="${2:-}"
                shift 2
                ;;
            -*)
                echo "Error: Unknown option: $1"
                echo "Usage: $0 <app-name> [--method helm|kustomize|manifest]"
                exit 1
                ;;
            *)
                app_name="$1"
                shift
                ;;
        esac
    done

    if [[ -z "$app_name" ]]; then
        echo "Usage: $0 <app-name> [--method helm|kustomize|manifest]"
        echo "Example: $0 postgres"
        echo "Example: $0 my-app --method kustomize"
        exit 1
    fi

    # Validate app name (lowercase, alphanumeric, hyphens)
    if [[ ! "$app_name" =~ ^[a-z][a-z0-9-]*$ ]]; then
        echo "Error: App name must be lowercase, start with a letter, and contain only [a-z0-9-]"
        exit 1
    fi

    # Validate deploy method
    case "$method" in
        helm|kustomize|manifest) ;;
        *)
            echo "Error: Invalid method '${method}'. Must be one of: helm, kustomize, manifest"
            exit 1
            ;;
    esac

    local app_dir="${APPS_DIR}/${app_name}"

    if [[ -d "$app_dir" ]]; then
        echo "Error: App directory already exists: ${app_dir}"
        exit 1
    fi

    # Select template directory
    local template_dir
    if [[ "$method" == "helm" ]]; then
        template_dir="${APPS_DIR}/_template"
    else
        template_dir="${APPS_DIR}/_template-${method}"
    fi

    if [[ ! -d "$template_dir" ]]; then
        echo "Error: Template directory not found: ${template_dir}"
        exit 1
    fi

    echo "Creating app: ${app_name} (method: ${method})"

    # Copy template
    cp -r "$template_dir" "$app_dir"

    # Replace APPNAME placeholders
    find "$app_dir" -type f | while IFS= read -r file; do
        if [[ "$(uname)" == "Darwin" ]]; then
            sed -i '' "s/APPNAME/${app_name}/g" "$file"
        else
            sed -i "s/APPNAME/${app_name}/g" "$file"
        fi
    done

    echo "App scaffolded at: ${app_dir}"
    echo ""
    echo "Next steps:"
    echo "  1. Edit ${app_dir}/app.yaml (set metadata, parameters, versions)"

    case "$method" in
        helm)
            echo "  2. Edit ${app_dir}/chart/Chart.yaml (set upstream dependency)"
            echo "  3. Edit ${app_dir}/chart/values.yaml (set defaults)"
            ;;
        kustomize)
            echo "  2. Edit ${app_dir}/kustomize/base/ manifests"
            echo "  3. Edit ${app_dir}/kustomize/overlays/single/ patches"
            ;;
        manifest)
            echo "  2. Edit ${app_dir}/manifests/ YAML files"
            ;;
    esac

    echo "  4. Edit ${app_dir}/cloud-init.yaml (set parameters for end users)"
    echo "  5. Edit ${app_dir}/cloud-init.sh (bash equivalent)"
    echo "  6. Update hooks as needed"
    echo "  7. Run: make validate"
    echo "  8. Run: make catalog"
}

main "$@"
