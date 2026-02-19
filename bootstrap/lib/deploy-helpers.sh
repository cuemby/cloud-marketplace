#!/usr/bin/env bash
# deploy-helpers.sh — Shared deployment helper functions.
# Used by kustomize and manifest deployers for envsubst, rollout waits, and cleanup.
# Source this file; do not execute directly.

# Substitute PARAM_* env vars in all YAML files within a directory (recursive).
# Uses an explicit variable list to avoid clobbering Kubernetes $(VAR) references.
# Mutates files in place — safe on single-use VMs.
# Usage: envsubst_yaml_files <directory>
envsubst_yaml_files() {
    local dir="$1"

    # Build explicit var list from current PARAM_* env vars
    local var_list
    var_list="$(env | sed -n 's/^\(PARAM_[A-Za-z0-9_]*\)=.*/\1/p' | sed 's/^/$/g' | tr '\n' ' ')"

    if [[ -z "$var_list" ]]; then
        log_debug "No PARAM_* vars found for envsubst, skipping."
        return 0
    fi

    local file
    while IFS= read -r file; do
        log_debug "envsubst: ${file}"
        local tmp="${file}.tmp"
        envsubst "$var_list" < "$file" > "$tmp"
        mv "$tmp" "$file"
    done < <(find "$dir" -type f \( -name '*.yaml' -o -name '*.yml' \))
}

# Wait for all Deployments, StatefulSets, and DaemonSets in a namespace to roll out.
# Usage: wait_for_rollout <namespace> <timeout_secs>
wait_for_rollout() {
    local namespace="$1"
    local timeout="$2"

    # Wait for Deployments
    local deployments
    deployments="$(kubectl get deployments -n "$namespace" --no-headers \
        -o custom-columns=NAME:.metadata.name 2>/dev/null || true)"
    if [[ -n "$deployments" ]]; then
        while IFS= read -r deploy; do
            [[ -z "$deploy" ]] && continue
            log_info "Waiting for deployment/${deploy} rollout..."
            if ! kubectl rollout status "deployment/${deploy}" \
                -n "$namespace" --timeout="${timeout}s" 2>&1; then
                log_error "Deployment ${deploy} failed to roll out."
                return 1
            fi
        done <<< "$deployments"
    fi

    # Wait for StatefulSets
    local statefulsets
    statefulsets="$(kubectl get statefulsets -n "$namespace" --no-headers \
        -o custom-columns=NAME:.metadata.name 2>/dev/null || true)"
    if [[ -n "$statefulsets" ]]; then
        while IFS= read -r sts; do
            [[ -z "$sts" ]] && continue
            log_info "Waiting for statefulset/${sts} rollout..."
            if ! kubectl rollout status "statefulset/${sts}" \
                -n "$namespace" --timeout="${timeout}s" 2>&1; then
                log_error "StatefulSet ${sts} failed to roll out."
                return 1
            fi
        done <<< "$statefulsets"
    fi

    # Wait for DaemonSets
    local daemonsets
    daemonsets="$(kubectl get daemonsets -n "$namespace" --no-headers \
        -o custom-columns=NAME:.metadata.name 2>/dev/null || true)"
    if [[ -n "$daemonsets" ]]; then
        while IFS= read -r ds; do
            [[ -z "$ds" ]] && continue
            log_info "Waiting for daemonset/${ds} rollout..."
            if ! kubectl rollout status "daemonset/${ds}" \
                -n "$namespace" --timeout="${timeout}s" 2>&1; then
                log_error "DaemonSet ${ds} failed to roll out."
                return 1
            fi
        done <<< "$daemonsets"
    fi

    return 0
}

# Dump pod status, events, and recent logs for debugging failed deployments.
# Called before atomic_cleanup so diagnostic data is preserved.
# Usage: _dump_namespace_diagnostics <namespace>
_dump_namespace_diagnostics() {
    local namespace="$1"

    log_warn "=== Diagnostic dump for namespace ${namespace} ==="

    log_warn "--- Pod status ---"
    kubectl get pods -n "$namespace" -o wide 2>/dev/null || true

    log_warn "--- Pod descriptions (non-Running) ---"
    local pods
    pods="$(kubectl get pods -n "$namespace" --no-headers \
        -o custom-columns=NAME:.metadata.name,STATUS:.status.phase 2>/dev/null \
        | grep -v Running | awk '{print $1}')" || true
    for pod in $pods; do
        [[ -z "$pod" ]] && continue
        log_warn "--- describe pod/${pod} ---"
        kubectl describe pod "$pod" -n "$namespace" 2>/dev/null | tail -30 || true
    done

    log_warn "--- Recent events ---"
    kubectl get events -n "$namespace" --sort-by='.lastTimestamp' 2>/dev/null | tail -20 || true

    log_warn "=== End diagnostic dump ==="
}

# Delete all resources in a namespace on failure (atomic cleanup).
# Equivalent of Helm's --atomic flag for non-Helm deploys.
# Usage: atomic_cleanup <namespace> <app_name>
atomic_cleanup() {
    local namespace="$1"
    local app_name="$2"

    log_warn "Performing atomic cleanup for ${app_name}..."

    kubectl delete all --all -n "$namespace" --timeout=60s 2>/dev/null || true
    kubectl delete pvc --all -n "$namespace" --timeout=60s 2>/dev/null || true
    kubectl delete configmaps --all -n "$namespace" 2>/dev/null || true
    kubectl delete secrets --field-selector type!=kubernetes.io/service-account-token \
        --all -n "$namespace" 2>/dev/null || true

    log_warn "Atomic cleanup complete. Namespace ${namespace} resources deleted."
}

# Resolve APP_VERSION to an imageTag from the versions list.
# For kustomize/manifest apps where versions map to container image tags.
# Usage: resolve_image_tag <app_yaml> <app_version>
resolve_image_tag() {
    local app_yaml="$1"
    local requested_version="$2"

    local version_count
    version_count="$(yq -r '.versions | length' "$app_yaml" 2>/dev/null)"

    if [[ "$version_count" == "0" ]] || [[ "$version_count" == "null" ]]; then
        echo "latest"
        return 0
    fi

    # Check if versions entries are objects (new-style) or strings (old-style)
    local first_type
    first_type="$(yq -r '.versions[0] | type' "$app_yaml" 2>/dev/null)"

    if [[ "$first_type" != "!!map" ]]; then
        # Old-style flat string array — use requested version or first entry
        if [[ -n "$requested_version" ]]; then
            echo "$requested_version"
        else
            yq -r '.versions[0]' "$app_yaml"
        fi
        return 0
    fi

    # New-style versionMap
    if [[ -n "$requested_version" ]]; then
        local found
        found="$(yq -r ".versions[] | select(.appVersion == \"${requested_version}\") | .imageTag" "$app_yaml" 2>/dev/null)"
        if [[ -n "$found" ]] && [[ "$found" != "null" ]]; then
            echo "$found"
            return 0
        fi
        log_warn "Requested version '${requested_version}' not found in versions, using default."
    fi

    # Use default entry, or fall back to first
    local default_tag
    default_tag="$(yq -r '.versions[] | select(.default == true) | .imageTag' "$app_yaml" 2>/dev/null)"
    if [[ -n "$default_tag" ]] && [[ "$default_tag" != "null" ]]; then
        echo "$default_tag"
    else
        yq -r '.versions[0].imageTag // "latest"' "$app_yaml"
    fi
}
