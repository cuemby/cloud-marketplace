#!/usr/bin/env bats
# test_validation.sh — Unit tests for bootstrap/lib/validation.sh

setup() {
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

    export LOG_FILE=""
    export LOG_LEVEL=1
    export APPS_DIR="${REPO_DIR}/apps"

    source "${REPO_DIR}/bootstrap/lib/constants.sh"
    source "${REPO_DIR}/bootstrap/lib/logging.sh"
    source "${REPO_DIR}/bootstrap/lib/validation.sh"
}

teardown() {
    # Clean up test fixture directories in case a test fails mid-way
    rm -rf "${APPS_DIR}/_test-fixture-version" 2>/dev/null || true
}

@test "validate_required_env succeeds when var is set" {
    export TEST_VAR="hello"
    run validate_required_env TEST_VAR
    [ "$status" -eq 0 ]
}

@test "validate_required_env fails when var is missing" {
    unset MISSING_VAR 2>/dev/null || true
    run validate_required_env MISSING_VAR
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Missing required environment variables" ]]
}

@test "validate_required_env fails when var is empty" {
    export EMPTY_VAR=""
    run validate_required_env EMPTY_VAR
    [ "$status" -eq 1 ]
}

@test "validate_required_env checks multiple vars" {
    export VAR_A="a"
    unset VAR_B 2>/dev/null || true
    run validate_required_env VAR_A VAR_B
    [ "$status" -eq 1 ]
    [[ "$output" =~ "VAR_B" ]]
}

@test "validate_app_exists succeeds for template app" {
    run validate_app_exists "_template"
    [ "$status" -eq 0 ]
}

@test "validate_app_exists fails for nonexistent app" {
    run validate_app_exists "nonexistent_app_xyz"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not found" ]]
}

@test "validate_app_version succeeds for new-style versionMap" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi
    local fixture="_test-fixture-version"
    mkdir -p "${APPS_DIR}/${fixture}"
    cat > "${APPS_DIR}/${fixture}/app.yaml" <<'EOF'
name: test-app
versions:
  - appVersion: "1.0.0"
    chartVersion: "10.0.0"
    default: true
  - appVersion: "0.9.0"
    chartVersion: "9.0.0"
EOF
    run validate_app_version "$fixture" "1.0.0"
    rm -rf "${APPS_DIR}/${fixture}"
    [ "$status" -eq 0 ]
}

@test "validate_app_version fails for invalid version in versionMap" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi
    local fixture="_test-fixture-version"
    mkdir -p "${APPS_DIR}/${fixture}"
    cat > "${APPS_DIR}/${fixture}/app.yaml" <<'EOF'
name: test-app
versions:
  - appVersion: "1.0.0"
    chartVersion: "10.0.0"
    default: true
EOF
    run validate_app_version "$fixture" "9.9.9"
    rm -rf "${APPS_DIR}/${fixture}"
    [ "$status" -eq 1 ]
}

@test "validate_app_version succeeds with no version specified" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi
    local fixture="_test-fixture-version"
    mkdir -p "${APPS_DIR}/${fixture}"
    cat > "${APPS_DIR}/${fixture}/app.yaml" <<'EOF'
name: test-app
versions:
  - appVersion: "1.0.0"
    chartVersion: "10.0.0"
    default: true
EOF
    run validate_app_version "$fixture" ""
    rm -rf "${APPS_DIR}/${fixture}"
    [ "$status" -eq 0 ]
}

@test "validate_app_version works with old-style flat array" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi
    local fixture="_test-fixture-version"
    mkdir -p "${APPS_DIR}/${fixture}"
    cat > "${APPS_DIR}/${fixture}/app.yaml" <<'EOF'
name: test-app
versions:
  - "1.0.0"
  - "0.9.0"
EOF
    run validate_app_version "$fixture" "1.0.0"
    local status1="$status"
    run validate_app_version "$fixture" "9.9.9"
    local status2="$status"
    rm -rf "${APPS_DIR}/${fixture}"
    [ "$status1" -eq 0 ]
    [ "$status2" -eq 1 ]
}
