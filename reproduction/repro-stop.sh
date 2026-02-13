#!/bin/bash
# =============================================================================
# Spring Cloud LoadBalancer with Kubernetes discovery and health checking issue - Reproduction cleanup script
# =============================================================================
# This script removes all Kubernetes resources created by repro-start.sh.
#
# Usage:
#   ./repro-stop.sh
#
# What it does:
#   - Deletes all Kubernetes resources defined in the k8s/ directory
#   - Does NOT stop or delete Minikube (see instructions below)
# =============================================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Cleaning up Kubernetes resources..."
echo "=========================================="

kubectl delete -f "$SCRIPT_DIR/k8s/" --ignore-not-found=true

echo ""
echo "Cleanup complete!"
echo ""
echo "To run the reproduction again:"
echo "  ./repro-start.sh              # Spring Boot 4 (issue version)"
echo "  ./repro-start.sh --springboot3  # Spring Boot 3 (working version)"
echo ""
echo "To stop minikube, run:"
echo "  minikube stop"
echo ""
echo "To delete minikube entirely, run:"
echo "  minikube delete"
