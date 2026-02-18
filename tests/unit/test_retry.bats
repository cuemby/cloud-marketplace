#!/usr/bin/env bats
# test_retry.sh — Unit tests for bootstrap/lib/retry.sh

setup() {
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

    export LOG_FILE=""
    export LOG_LEVEL=1

    source "${REPO_DIR}/bootstrap/lib/logging.sh"
    source "${REPO_DIR}/bootstrap/lib/retry.sh"
}

@test "retry_with_timeout succeeds on first try" {
    run retry_with_timeout 5 1 true
    [ "$status" -eq 0 ]
}

@test "retry_with_timeout fails after timeout" {
    run retry_with_timeout 2 1 false
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Timed out" ]]
}

@test "retry_with_backoff succeeds on first try" {
    run retry_with_backoff 3 1 5 true
    [ "$status" -eq 0 ]
}

@test "retry_with_backoff fails after max attempts" {
    run retry_with_backoff 2 1 2 false
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Failed after" ]]
}
