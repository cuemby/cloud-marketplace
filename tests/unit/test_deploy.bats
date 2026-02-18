#!/usr/bin/env bats
# test_deploy.sh — Unit tests for deployment logic (version resolution)

setup() {
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

    export LOG_FILE=""
    export LOG_LEVEL=1
    export APPS_DIR="${REPO_DIR}/apps"

    source "${REPO_DIR}/bootstrap/lib/constants.sh"
    source "${REPO_DIR}/bootstrap/lib/logging.sh"
    source "${REPO_DIR}/bootstrap/lib/retry.sh"
    source "${REPO_DIR}/bootstrap/lib/deploy-helpers.sh"
    source "${REPO_DIR}/bootstrap/deploy-helm.sh"
}

# --- resolve_chart_version tests ---

@test "resolve_chart_version returns chart.version when no versions list" {
    if ! command -v yq &>/dev/null; then skip "yq not installed"; fi
    local tmp
    tmp="$(mktemp)"
    cat > "$tmp" <<'EOF'
chart:
  version: "1.0.0"
EOF
    run resolve_chart_version "$tmp" ""
    [ "$status" -eq 0 ]
    [ "$output" = "1.0.0" ]
    rm "$tmp"
}

@test "resolve_chart_version returns chart.version for old-style flat array" {
    if ! command -v yq &>/dev/null; then skip "yq not installed"; fi
    local tmp
    tmp="$(mktemp)"
    cat > "$tmp" <<'EOF'
chart:
  version: "1.0.0"
versions:
  - "1.0.0"
  - "0.9.0"
EOF
    run resolve_chart_version "$tmp" ""
    [ "$status" -eq 0 ]
    [ "$output" = "1.0.0" ]
    rm "$tmp"
}

@test "resolve_chart_version resolves requested appVersion to chartVersion" {
    if ! command -v yq &>/dev/null; then skip "yq not installed"; fi
    local tmp
    tmp="$(mktemp)"
    cat > "$tmp" <<'EOF'
chart:
  version: "10.0.0"
versions:
  - appVersion: "1.0.0"
    chartVersion: "10.0.0"
    default: true
  - appVersion: "0.9.0"
    chartVersion: "9.0.0"
EOF
    run resolve_chart_version "$tmp" "0.9.0"
    [ "$status" -eq 0 ]
    [ "$output" = "9.0.0" ]
    rm "$tmp"
}

@test "resolve_chart_version returns default when no version requested" {
    if ! command -v yq &>/dev/null; then skip "yq not installed"; fi
    local tmp
    tmp="$(mktemp)"
    cat > "$tmp" <<'EOF'
chart:
  version: "10.0.0"
versions:
  - appVersion: "1.0.0"
    chartVersion: "10.0.0"
  - appVersion: "0.9.0"
    chartVersion: "9.0.0"
    default: true
EOF
    run resolve_chart_version "$tmp" ""
    [ "$status" -eq 0 ]
    [ "$output" = "9.0.0" ]
    rm "$tmp"
}

@test "resolve_chart_version falls back to first entry when no default" {
    if ! command -v yq &>/dev/null; then skip "yq not installed"; fi
    local tmp
    tmp="$(mktemp)"
    cat > "$tmp" <<'EOF'
chart:
  version: "10.0.0"
versions:
  - appVersion: "1.0.0"
    chartVersion: "10.0.0"
  - appVersion: "0.9.0"
    chartVersion: "9.0.0"
EOF
    run resolve_chart_version "$tmp" ""
    [ "$status" -eq 0 ]
    [ "$output" = "10.0.0" ]
    rm "$tmp"
}

# --- resolve_image_tag tests ---

@test "resolve_image_tag returns latest when no versions" {
    if ! command -v yq &>/dev/null; then skip "yq not installed"; fi
    local tmp
    tmp="$(mktemp)"
    cat > "$tmp" <<'EOF'
name: test-app
EOF
    run resolve_image_tag "$tmp" ""
    [ "$status" -eq 0 ]
    [ "$output" = "latest" ]
    rm "$tmp"
}

@test "resolve_image_tag resolves appVersion to imageTag" {
    if ! command -v yq &>/dev/null; then skip "yq not installed"; fi
    local tmp
    tmp="$(mktemp)"
    cat > "$tmp" <<'EOF'
versions:
  - appVersion: "1.2.0"
    imageTag: "v1.2.0"
    default: true
  - appVersion: "1.1.0"
    imageTag: "v1.1.0"
EOF
    run resolve_image_tag "$tmp" "1.1.0"
    [ "$status" -eq 0 ]
    [ "$output" = "v1.1.0" ]
    rm "$tmp"
}

@test "resolve_image_tag returns default imageTag when no version requested" {
    if ! command -v yq &>/dev/null; then skip "yq not installed"; fi
    local tmp
    tmp="$(mktemp)"
    cat > "$tmp" <<'EOF'
versions:
  - appVersion: "1.2.0"
    imageTag: "v1.2.0"
  - appVersion: "1.1.0"
    imageTag: "v1.1.0"
    default: true
EOF
    run resolve_image_tag "$tmp" ""
    [ "$status" -eq 0 ]
    [ "$output" = "v1.1.0" ]
    rm "$tmp"
}
