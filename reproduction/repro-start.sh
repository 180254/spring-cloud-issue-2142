#!/bin/bash
# =============================================================================
# Spring Cloud LoadBalancer with Kubernetes discovery and health checking issue - Reproduction start Script
# =============================================================================
# This script sets up a Kubernetes environment to reproduce the issue where
# Spring Cloud LoadBalancer stops working when health check is enabled in
# Spring Boot 4, while the same configuration works in Spring Boot 3.
#
# Usage:
#   ./repro-start.sh              # Run with Spring Boot 4 (reproduces the issue)
#   ./repro-start.sh --springboot3  # Run with Spring Boot 3 (working version)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Parse arguments
USE_SPRING_BOOT_3=false
for arg in "$@"; do
  case $arg in
  --springboot3)
    USE_SPRING_BOOT_3=true
    shift
    ;;
  --help | -h)
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --springboot3   Use Spring Boot 3.5.10 (working version)"
    echo "                  Default: Spring Boot 4.0.2 (issue version)"
    echo "  -h, --help      Show this help message"
    exit 0
    ;;
  esac
done

echo "=========================================="
echo "Spring Cloud LoadBalancer with Kubernetes discovery and health checking issue reproduction"
echo "=========================================="
if [ "$USE_SPRING_BOOT_3" = true ]; then
  echo "Mode: Spring Boot 3.5.10 + Spring Cloud 2025.0.1 (WORKING)"
  echo "POM:  pom2.xml"
else
  echo "Mode: Spring Boot 4.0.2 + Spring Cloud 2025.1.1 (ISSUE)"
  echo "POM:  pom.xml"
fi
echo "=========================================="

# Step 1: Build backend
echo ""
echo "[1/6] Building backend application..."
cd "$PROJECT_ROOT/backend"
./mvnw clean package -DskipTests
echo "Backend built successfully!"

# Step 2: Build front
echo ""
echo "[2/6] Building front application..."
cd "$PROJECT_ROOT/front"
if [ "$USE_SPRING_BOOT_3" = true ]; then
  ./mvnw -f pom2.xml clean package -DskipTests
else
  ./mvnw -f pom.xml clean package -DskipTests
fi
echo "front built successfully!"

# Step 3: Start minikube if not running
echo ""
echo "[3/6] Checking minikube status..."
if ! minikube status 2>/dev/null | grep -q "Running"; then
  echo "Starting minikube..."
  minikube start
else
  echo "Minikube is already running."
fi

# Step 4: Configure docker to use minikube's docker daemon
echo ""
echo "[4/6] Configuring Docker to use Minikube's daemon..."
eval $(minikube docker-env)

# Step 5: Build Docker images
echo ""
echo "[5/6] Building Docker images..."
cd "$SCRIPT_DIR"

echo "Building backend image..."
docker build -t backend:latest -f dockerfiles/backend.Dockerfile "$PROJECT_ROOT/backend"

echo "Building front image..."
docker build -t front:latest -f dockerfiles/front.Dockerfile "$PROJECT_ROOT/front"

echo "Docker images built successfully!"

echo "Cleaning up Kubernetes resources..."
kubectl delete -f "$SCRIPT_DIR/k8s/" --ignore-not-found=true

# Step 6: Apply Kubernetes manifests
echo ""
echo "[6/6] Applying Kubernetes manifests..."
kubectl apply -f "$SCRIPT_DIR/k8s/app-service-account.yaml"
kubectl apply -f "$SCRIPT_DIR/k8s/backend-deployment.yaml"
kubectl apply -f "$SCRIPT_DIR/k8s/backend-service.yaml"
kubectl apply -f "$SCRIPT_DIR/k8s/front-deployment.yaml"

echo ""
echo "Waiting for deployments to be ready..."
kubectl rollout status deployment/backend-deployment --timeout=120s
kubectl rollout status deployment/front-deployment --timeout=120s

echo ""
echo "=========================================="
echo "Reproduction setup complete!"
echo "=========================================="
echo ""
if [ "$USE_SPRING_BOOT_3" = true ]; then
  echo "Running with: Spring Boot 3.5.10 + Spring Cloud 2025.0.1"
  echo "Expected: LoadBalancer should work correctly ✅"
else
  echo "Running with: Spring Boot 4.0.2 + Spring Cloud 2025.1.1"
  echo "Expected: LoadBalancer fails when health-check is enabled ❌"
fi
echo ""
echo "Current pods:"
kubectl get pods -o wide
echo ""
echo "Current services:"
kubectl get services
echo ""
echo "To test the issue, run:"
echo "  kubectl port-forward deployment/front-deployment 8080:8080"
echo "  curl http://localhost:8080/"
echo ""
