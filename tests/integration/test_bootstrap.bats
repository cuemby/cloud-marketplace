#!/usr/bin/env bats
# test_bootstrap.sh — Integration tests for the full bootstrap flow.
#
# These tests validate the structure and scripts can be loaded,
# not the full K3s deployment (which requires systemd/privileged containers).

setup() {
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
}

@test "all bootstrap scripts have valid syntax" {
    for script in \
        "${REPO_DIR}/bootstrap/entrypoint.sh" \
        "${REPO_DIR}/bootstrap/install-k3s.sh" \
        "${REPO_DIR}/bootstrap/install-helm.sh" \
        "${REPO_DIR}/bootstrap/deploy-app.sh" \
        "${REPO_DIR}/bootstrap/deploy-helm.sh" \
        "${REPO_DIR}/bootstrap/deploy-kustomize.sh" \
        "${REPO_DIR}/bootstrap/deploy-manifest.sh" \
        "${REPO_DIR}/bootstrap/healthcheck.sh"; do
        bash -n "$script"
    done
}

@test "all lib scripts have valid syntax" {
    for script in "${REPO_DIR}"/bootstrap/lib/*.sh; do
        bash -n "$script"
    done
}

@test "all template hook scripts have valid syntax" {
    for template_dir in _template _template-kustomize _template-manifest; do
        local hooks_dir="${REPO_DIR}/apps/${template_dir}/hooks"
        if [[ -d "$hooks_dir" ]]; then
            for script in "${hooks_dir}"/*.sh; do
                bash -n "$script"
            done
        fi
    done
}

@test "template app.yaml files are valid YAML" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi
    for template_dir in _template _template-kustomize _template-manifest; do
        local app_yaml="${REPO_DIR}/apps/${template_dir}/app.yaml"
        if [[ -f "$app_yaml" ]]; then
            run yq '.' "$app_yaml"
            [ "$status" -eq 0 ]
        fi
    done
}

@test "helm template has chart directory" {
    [ -d "${REPO_DIR}/apps/_template/chart" ]
    [ -f "${REPO_DIR}/apps/_template/chart/Chart.yaml" ]
}

@test "kustomize template has kustomize directory" {
    [ -d "${REPO_DIR}/apps/_template-kustomize/kustomize/base" ]
    [ -f "${REPO_DIR}/apps/_template-kustomize/kustomize/base/kustomization.yaml" ]
}

@test "manifest template has manifests directory" {
    [ -d "${REPO_DIR}/apps/_template-manifest/manifests" ]
}

@test "each template has cloud-init files" {
    for template_dir in _template _template-kustomize _template-manifest; do
        local dir="${REPO_DIR}/apps/${template_dir}"
        [ -f "${dir}/cloud-init.yaml" ]
        [ -f "${dir}/cloud-init.sh" ]
    done
}

@test "each template declares correct deployMethod" {
    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi
    local method
    method="$(yq -r '.deployMethod // "helm"' "${REPO_DIR}/apps/_template/app.yaml")"
    [ "$method" = "helm" ]

    method="$(yq -r '.deployMethod' "${REPO_DIR}/apps/_template-kustomize/app.yaml")"
    [ "$method" = "kustomize" ]

    method="$(yq -r '.deployMethod' "${REPO_DIR}/apps/_template-manifest/app.yaml")"
    [ "$method" = "manifest" ]
}

@test "scripts have valid syntax" {
    for script in "${REPO_DIR}"/scripts/*.sh; do
        bash -n "$script"
    done
}
