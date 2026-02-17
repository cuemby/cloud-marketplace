#!/usr/bin/env bash
# logging.sh — Structured logging with timestamps and levels.
# Source this file; do not execute directly.

# Log level: DEBUG=0, INFO=1, WARN=2, ERROR=3, FATAL=4
LOG_LEVEL="${LOG_LEVEL:-1}"

_log() {
    local level="$1"
    local level_name="$2"
    shift 2
    local message="$*"
    local timestamp
    timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    if [[ "$level" -ge "$LOG_LEVEL" ]]; then
        local line="[${timestamp}] [${level_name}] ${message}"
        echo "$line" >&2
        if [[ -n "${LOG_FILE:-}" ]] && [[ -d "$(dirname "${LOG_FILE}")" ]]; then
            echo "$line" >> "$LOG_FILE"
        fi
    fi
}

log_debug() {
    _log 0 "DEBUG" "$@"
}

log_info() {
    _log 1 "INFO" "$@"
}

log_warn() {
    _log 2 "WARN" "$@"
}

log_error() {
    _log 3 "ERROR" "$@"
}

log_fatal() {
    _log 4 "FATAL" "$@"
    exit 1
}

# Log a section header for visual separation
log_section() {
    log_info "========================================"
    log_info "$*"
    log_info "========================================"
}
