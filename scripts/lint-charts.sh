#!/usr/bin/env bash
# lint-charts.sh — Run helm lint on all application charts.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
APPS_DIR="${REPO_DIR}/apps"

errors=0

main() {
    echo "==> Linting all Helm charts..."

    local chart_dirs
    chart_dirs="$(find "$APPS_DIR" -maxdepth 2 -name 'Chart.yaml' -not -path '*/_template/*' -exec dirname {} \; | sort)"

    if [[ -z "$chart_dirs" ]]; then
        echo "No charts found."
        exit 0
    fi

    while IFS= read -r chart_dir; do
        local app_name
        app_name="$(basename "$(dirname "$chart_dir")")"
        echo "Linting: ${app_name}"

        if ! helm lint "$chart_dir" 2>&1; then
            echo "  FAILED: ${app_name}"
            errors=$((errors + 1))
        fi
    done <<< "$chart_dirs"

    if [[ $errors -gt 0 ]]; then
        echo ""
        echo "FAILED: ${errors} chart(s) failed linting."
        exit 1
    fi

    echo ""
    echo "All charts passed linting."
}

main "$@"
