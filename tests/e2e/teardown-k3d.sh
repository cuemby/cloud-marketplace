#!/usr/bin/env bash
# teardown-k3d.sh — Delete the k3d E2E test cluster.
set -euo pipefail

CLUSTER_NAME="${K3D_CLUSTER_NAME:-e2e-test}"
k3d cluster delete "$CLUSTER_NAME" 2>/dev/null || true
echo "k3d cluster '${CLUSTER_NAME}' deleted."
