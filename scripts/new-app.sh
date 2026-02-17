#!/usr/bin/env bash
# new-app.sh — Scaffold a new application from the _template.
# Usage: ./scripts/new-app.sh <app-name>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="${REPO_DIR}/apps/_template"
APPS_DIR="${REPO_DIR}/apps"

main() {
    local app_name="${1:-}"

    if [[ -z "$app_name" ]]; then
        echo "Usage: $0 <app-name>"
        echo "Example: $0 postgres"
        exit 1
    fi

    # Validate app name (lowercase, alphanumeric, hyphens)
    if [[ ! "$app_name" =~ ^[a-z][a-z0-9-]*$ ]]; then
        echo "Error: App name must be lowercase, start with a letter, and contain only [a-z0-9-]"
        exit 1
    fi

    local app_dir="${APPS_DIR}/${app_name}"

    if [[ -d "$app_dir" ]]; then
        echo "Error: App directory already exists: ${app_dir}"
        exit 1
    fi

    echo "Creating app: ${app_name}"

    # Copy template
    cp -r "$TEMPLATE_DIR" "$app_dir"

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
    echo "  1. Edit ${app_dir}/app.yaml (set upstream chart, parameters)"
    echo "  2. Edit ${app_dir}/chart/Chart.yaml (set dependency)"
    echo "  3. Edit ${app_dir}/chart/values.yaml (set defaults)"
    echo "  4. Edit ${app_dir}/cloud-init.yaml (set parameters for end users)"
    echo "  5. Edit ${app_dir}/cloud-init.sh (bash equivalent for providers without YAML cloud-init)"
    echo "  6. Update hooks as needed"
    echo "  7. Run: make validate"
    echo "  8. Run: make catalog"
}

main "$@"
