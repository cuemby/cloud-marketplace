#!/usr/bin/env bash
# generate-catalog.sh — Build catalog.json from all apps/*/app.yaml files.
# Output: catalog/catalog.json
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
APPS_DIR="${REPO_DIR}/apps"
CATALOG_DIR="${REPO_DIR}/catalog"
CATALOG_FILE="${CATALOG_DIR}/catalog.json"

main() {
    mkdir -p "$CATALOG_DIR"

    local app_dirs
    app_dirs="$(find "$APPS_DIR" -maxdepth 2 -name 'app.yaml' -not -path '*/_template/*' | sort)"

    if [[ -z "$app_dirs" ]]; then
        echo "No apps found in ${APPS_DIR}"
        echo '{"apps":[],"generated":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}' > "$CATALOG_FILE"
        exit 0
    fi

    local entries="[]"
    while IFS= read -r app_yaml; do
        local entry
        entry="$(yq -o=json '.' "$app_yaml")"
        entries="$(echo "$entries" | jq --argjson e "$entry" '. + [$e]')"
    done <<< "$app_dirs"

    local catalog
    catalog="$(jq -n \
        --argjson apps "$entries" \
        --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        '{apps: $apps, generated: $ts}')"

    echo "$catalog" > "$CATALOG_FILE"
    echo "Catalog generated: ${CATALOG_FILE} ($(echo "$entries" | jq 'length') apps)"
}

main "$@"
