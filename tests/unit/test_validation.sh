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

@test "validate_app_exists succeeds for wordpress" {
    run validate_app_exists "wordpress"
    [ "$status" -eq 0 ]
}

@test "validate_app_exists fails for nonexistent app" {
    run validate_app_exists "nonexistent_app_xyz"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not found" ]]
}
