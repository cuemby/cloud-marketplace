#!/usr/bin/env bats
# test_logging.sh — Unit tests for bootstrap/lib/logging.sh

setup() {
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

    # Unset LOG_FILE to avoid writing to real log
    export LOG_FILE=""
    export LOG_LEVEL=0

    source "${REPO_DIR}/bootstrap/lib/logging.sh"
}

@test "log_info outputs INFO level message" {
    run log_info "test message"
    [[ "$output" =~ "[INFO] test message" ]]
}

@test "log_error outputs ERROR level message" {
    run log_error "something went wrong"
    [[ "$output" =~ "[ERROR] something went wrong" ]]
}

@test "log_warn outputs WARN level message" {
    run log_warn "warning here"
    [[ "$output" =~ "[WARN] warning here" ]]
}

@test "log_debug outputs DEBUG level message when level is 0" {
    export LOG_LEVEL=0
    source "${REPO_DIR}/bootstrap/lib/logging.sh"
    run log_debug "debug details"
    [[ "$output" =~ "[DEBUG] debug details" ]]
}

@test "log_debug is suppressed when LOG_LEVEL is 1 (INFO)" {
    export LOG_LEVEL=1
    source "${REPO_DIR}/bootstrap/lib/logging.sh"
    run log_debug "should not appear"
    [[ -z "$output" ]]
}

@test "log_section outputs section header" {
    run log_section "My Section"
    [[ "$output" =~ "========" ]]
    [[ "$output" =~ "My Section" ]]
}

@test "log messages include ISO timestamp" {
    run log_info "timestamp check"
    [[ "$output" =~ "[20" ]]
    [[ "$output" =~ "T" ]]
    [[ "$output" =~ "Z]" ]]
}
