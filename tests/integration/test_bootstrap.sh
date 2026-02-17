#!/usr/bin/env bats
# test_bootstrap.sh — Integration tests for the full bootstrap flow.
# Requires Docker. Runs the bootstrap in an Ubuntu container.
#
# These tests validate the structure and scripts can be loaded,
# not the full K3s deployment (which requires systemd/privileged containers).

setup() {
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
}

@test "all bootstrap scripts are executable or can be sourced" {
    for script in \
        "${REPO_DIR}/bootstrap/entrypoint.sh" \
        "${REPO_DIR}/bootstrap/install-k3s.sh" \
        "${REPO_DIR}/bootstrap/install-helm.sh" \
        "${REPO_DIR}/bootstrap/deploy-app.sh" \
        "${REPO_DIR}/bootstrap/healthcheck.sh"; do
        bash -n "$script"
    done
}

@test "all lib scripts have valid syntax" {
    for script in "${REPO_DIR}"/bootstrap/lib/*.sh; do
        bash -n "$script"
    done
}

@test "all hook scripts have valid syntax" {
    for script in "${REPO_DIR}"/apps/wordpress/hooks/*.sh; do
        bash -n "$script"
    done
}

@test "wordpress app.yaml is valid YAML" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi
    run yq '.' "${REPO_DIR}/apps/wordpress/app.yaml"
    [ "$status" -eq 0 ]
}

@test "wordpress Chart.yaml is valid YAML" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi
    run yq '.' "${REPO_DIR}/apps/wordpress/chart/Chart.yaml"
    [ "$status" -eq 0 ]
}

@test "wordpress app.yaml has required fields" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi
    local name
    name="$(yq -r '.name' "${REPO_DIR}/apps/wordpress/app.yaml")"
    [ "$name" = "wordpress" ]
}

@test "scripts have valid syntax" {
    for script in "${REPO_DIR}"/scripts/*.sh; do
        bash -n "$script"
    done
}
