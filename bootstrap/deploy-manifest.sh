#!/usr/bin/env bash
# deploy-manifest.sh — Raw manifest deployment strategy.
# Deploys an application by applying YAML manifests with PARAM_* envsubst.
# Source this file; do not execute directly.

# Deploy an application using raw YAML manifests.
# Reads config from app.yaml, substitutes PARAM_* vars via envsubst,
# applies manifests in order, waits for rollout, and cleans up on failure.
# Usage: deploy_manifest <app_name> <app_dir> <app_yaml> <namespace>
deploy_manifest() {
    local app_name="$1"
    local app_dir="$2"
    local app_yaml="$3"
    local namespace="$4"

    # Read manifest config from app.yaml
    local manifests_path
    manifests_path="$(yq -r '.manifests.path // "manifests/"' "$app_yaml")"
    local manifests_dir="${app_dir}/${manifests_path}"

    if [[ ! -d "$manifests_dir" ]]; then
        log_fatal "Manifests directory not found: ${manifests_dir}"
    fi

    # Resolve APP_VERSION to image tag and export for envsubst
    local image_tag
    image_tag="$(resolve_image_tag "$app_yaml" "${APP_VERSION:-}")"
    export PARAM_APP_IMAGE_TAG="${image_tag}"
    log_info "Image tag resolved: ${image_tag}"

    # Determine manifest apply order
    local manifest_files=()
    local explicit_order
    explicit_order="$(yq -r '.manifests.order // [] | .[]' "$app_yaml" 2>/dev/null)"

    if [[ -n "$explicit_order" ]]; then
        # Use explicit order from app.yaml
        while IFS= read -r filename; do
            local filepath="${manifests_dir}/${filename}"
            if [[ -f "$filepath" ]]; then
                manifest_files+=("$filepath")
            else
                log_warn "Manifest file listed in order but not found: ${filepath}"
            fi
        done <<< "$explicit_order"
    else
        # Lexicographic order (numeric prefix convention: 00-foo.yaml, 10-bar.yaml)
        while IFS= read -r filepath; do
            manifest_files+=("$filepath")
        done < <(find "$manifests_dir" -maxdepth 1 \( -name '*.yaml' -o -name '*.yml' \) -type f | sort)
    fi

    if [[ ${#manifest_files[@]} -eq 0 ]]; then
        log_fatal "No manifest files found in ${manifests_dir}"
    fi

    # Build explicit PARAM_* var list for envsubst (protects Kubernetes $(VAR) syntax)
    local var_list
    var_list="$(env | sed -n 's/^\(PARAM_[A-Za-z0-9_]*\)=.*/\1/p' | sed 's/^/$/g' | tr '\n' ' ')"

    # Apply each manifest with envsubst
    log_info "Deploying ${app_name} via manifests (${#manifest_files[@]} files, namespace: ${namespace})..."

    for manifest in "${manifest_files[@]}"; do
        local basename
        basename="$(basename "$manifest")"
        log_info "Applying: ${basename}"

        if [[ -n "$var_list" ]]; then
            if ! envsubst "$var_list" < "$manifest" | kubectl apply -n "$namespace" -f -; then
                log_error "Failed to apply ${basename} — cleaning up."
                atomic_cleanup "$namespace" "$app_name"
                return 1
            fi
        else
            if ! kubectl apply -n "$namespace" -f "$manifest"; then
                log_error "Failed to apply ${basename} — cleaning up."
                atomic_cleanup "$namespace" "$app_name"
                return 1
            fi
        fi
    done

    # Wait for all workloads to complete rollout
    log_info "Waiting for rollout to complete (timeout: ${TIMEOUT_HELM_DEPLOY}s)..."
    if ! wait_for_rollout "$namespace" "$TIMEOUT_HELM_DEPLOY"; then
        log_error "Rollout timed out — dumping diagnostics before cleanup."
        _dump_namespace_diagnostics "$namespace"
        atomic_cleanup "$namespace" "$app_name"
        return 1
    fi

    log_info "Manifest deployment completed successfully."
}
