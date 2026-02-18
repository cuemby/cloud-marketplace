#!/usr/bin/env bash
# setup-k3d.sh — Create a k3d cluster for E2E testing.
set -euo pipefail

CLUSTER_NAME="${K3D_CLUSTER_NAME:-e2e-test}"

# Delete existing cluster if present
k3d cluster delete "$CLUSTER_NAME" 2>/dev/null || true

# Create single-node cluster (Traefik enabled by default in K3s)
k3d cluster create "$CLUSTER_NAME" \
    --wait \
    --timeout 120s \
    --k3s-arg "--disable=servicelb@server:0" \
    --no-lb

# Wait for node readiness
kubectl wait --for=condition=Ready nodes --all --timeout=120s

# Wait for CoreDNS
kubectl wait --for=condition=Ready pod \
    -l k8s-app=kube-dns \
    -n kube-system \
    --timeout=120s

echo "k3d cluster '${CLUSTER_NAME}' is ready."
