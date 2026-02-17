#!/usr/bin/env bash
# retry.sh — Retry utilities with timeout and backoff.
# Source this file; do not execute directly.

# Retry a command with a fixed interval until timeout.
# Usage: retry_with_timeout <timeout_secs> <interval_secs> <command...>
retry_with_timeout() {
    local timeout="$1"
    local interval="$2"
    shift 2

    local deadline
    deadline=$((SECONDS + timeout))

    while [[ $SECONDS -lt $deadline ]]; do
        if "$@" 2>/dev/null; then
            return 0
        fi
        log_debug "Retrying in ${interval}s: $*"
        sleep "$interval"
    done

    log_error "Timed out after ${timeout}s: $*"
    return 1
}

# Retry a command with exponential backoff.
# Usage: retry_with_backoff <max_attempts> <initial_interval> <max_interval> <command...>
retry_with_backoff() {
    local max_attempts="$1"
    local interval="$2"
    local max_interval="$3"
    shift 3

    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if "$@" 2>/dev/null; then
            return 0
        fi

        if [[ $attempt -eq $max_attempts ]]; then
            log_error "Failed after ${max_attempts} attempts: $*"
            return 1
        fi

        log_debug "Attempt ${attempt}/${max_attempts} failed, retrying in ${interval}s: $*"
        sleep "$interval"

        interval=$((interval * 2))
        if [[ $interval -gt $max_interval ]]; then
            interval=$max_interval
        fi
        attempt=$((attempt + 1))
    done
}
