#!/usr/bin/env bash
# deploy-kustomize.sh — Kustomize deployment strategy.
# Deploys an application using kubectl kustomize with PARAM_* envsubst.
# Source this file; do not execute directly.

# Deploy an application using Kustomize.
# Reads config from app.yaml, substitutes PARAM_* vars via envsubst,
# applies with kubectl, waits for rollout, and cleans up on failure.
# Usage: deploy_kustomize <app_name> <app_dir> <app_yaml> <namespace>
deploy_kustomize() {
    local app_name="$1"
    local app_dir="$2"
    local app_yaml="$3"
    local namespace="$4"

    # Read kustomize config from app.yaml
    local base_path overlays_path
    base_path="$(yq -r '.kustomize.basePath // "kustomize/base"' "$app_yaml")"
    overlays_path="$(yq -r '.kustomize.overlaysPath // "kustomize/overlays"' "$app_yaml")"

    # Select kustomize directory: overlay (by profile) or base
    local profile="${VM_PROFILE:-single}"
    local overlay_dir="${app_dir}/${overlays_path}/${profile}"
    local kustomize_dir

    if [[ -d "$overlay_dir" ]]; then
        kustomize_dir="$overlay_dir"
        log_info "Using kustomize overlay: ${profile}"
    else
        kustomize_dir="${app_dir}/${base_path}"
        log_info "Using kustomize base (no overlay for profile: ${profile})"
    fi

    if [[ ! -d "$kustomize_dir" ]]; then
        log_fatal "Kustomize directory not found: ${kustomize_dir}"
    fi

    # Resolve APP_VERSION to image tag and export for envsubst
    local image_tag
    image_tag="$(resolve_image_tag "$app_yaml" "${APP_VERSION:-}")"
    export PARAM_APP_IMAGE_TAG="${image_tag}"
    log_info "Image tag resolved: ${image_tag}"

    # Substitute PARAM_* env vars into kustomize manifests (in-place, safe on single-use VMs)
    log_info "Substituting PARAM_* env vars into kustomize manifests..."
    envsubst_yaml_files "$kustomize_dir"

    # Build and apply kustomize output
    log_info "Deploying ${app_name} via kustomize (namespace: ${namespace})..."
    if ! kubectl kustomize "$kustomize_dir" | kubectl apply -n "$namespace" -f -; then
        log_error "Kustomize apply failed — cleaning up namespace."
        atomic_cleanup "$namespace" "$app_name"
        return 1
    fi

    # Wait for all workloads to complete rollout
    log_info "Waiting for rollout to complete (timeout: ${TIMEOUT_HELM_DEPLOY}s)..."
    if ! wait_for_rollout "$namespace" "$TIMEOUT_HELM_DEPLOY"; then
        log_error "Rollout timed out — cleaning up namespace."
        atomic_cleanup "$namespace" "$app_name"
        return 1
    fi

    log_info "Kustomize deployment completed successfully."
}
