# Spring Cloud LoadBalancer with Kubernetes discovery and health checking issue - reproduction (spring boot 4.0.2 + spring cloud 2025.1.1)

This repository reproduces an issue where Spring Cloud LoadBalancer with Kubernetes discovery stops working
when health check is enabled in Spring Boot 4, while the same code works correctly with Spring Boot 3.

Issue report: https://github.com/spring-cloud/spring-cloud-kubernetes/issues/2142

## The issue

When using Spring Cloud LoadBalancer with Kubernetes discovery and enabling the health check configuration:

```yaml
spring:
  cloud:
    loadbalancer:
      health-check:
        path:
          backend-service: /healthcheck
      configurations: health-check
```

I have observed that:
- **Spring Boot 3.5.10 + Spring Cloud 2025.0.1**: LoadBalancer works correctly ✅
- **Spring Boot 4.0.2 + Spring Cloud 2025.1.1**: LoadBalancer fails to route requests ❌
- **Spring Boot 4.0.2 + Spring Cloud 2025.1.1** + loadbalancer `configurations: default`: LoadBalancer works correctly ✅

## Prerequisites

- docker
- minikube
- kubectl (optional)

## Quick start

### Prepare environment

```bash
alias kubectl="minikube kubectl --" # optional
```

### Reproduce the Issue with Spring Boot 4 (default)

Run the script (it will compile the application and prepare the environment),<br/>
port forward the front service and make a request:

```bash
./reproduction/repro-start.sh
kubectl port-forward deployment/front-deployment 8080:8080
curl http://localhost:8080/
```

**Actual result with Spring Boot 4**: Request fails / times out
**Expected result with Spring Boot 4**: Returns `DONE` from backend

### Test with Spring Boot 3 (working version)

Run the script (it will compile the application and prepare the environment),<br/>
port forward the front service and make a request:

```bash
./reproduction/repro-start.sh --springboot3
kubectl port-forward deployment/front-deployment 8080:8080
curl http://localhost:8080/
```

**Actual result with Spring Boot 3**: Returns `DONE` from backend (functioning correctly)

## What the script does

The `repro-start.sh` script performs the following steps:

1. **Build backend application** - Compiles the backend service using Maven
2. **Build front application** - Compiles the front service using Maven
    - Uses `pom.xml` (Spring Boot 4) by default
    - Uses `pom2.xml` (Spring Boot 3) when `--springboot3` flag is provided
3. **Start Minikube** - Starts a local Kubernetes cluster if not already running
4. **Configure Docker** - Points Docker to Minikube's Docker daemon
5. **Build Docker images** - Creates container images for both applications
6. **Deploy to Kubernetes** - Applies all Kubernetes manifests and waits for deployments

## Cleanup

Run the cleanup script:

```bash
./reproduction/repro-stop.sh
```

## Manual Steps

Please review the source of the `repro-start.sh` and `repro-stop.sh` files to see the exact list of steps.

## Files

- `backend` - Backend application (this is the application we want to connect to).
- `front` - Frontend application (this application uses Spring Boot&Cloud — **this is where the issue occurs**).
- `repro-start.sh` - Main reproduction script (supports `--springboot3` flag)
- `repro-stop.sh` - Cleanup script to remove Kubernetes resources
- `dockerfiles/` - Dockerfile definitions
    - `backend.Dockerfile` - Dockerfile for backend application
    - `front.Dockerfile` - Dockerfile for front application
- `k8s/` - Kubernetes manifests
    - `app-service-account.yaml` - ServiceAccount, Role, and RoleBinding for Kubernetes API access
    - `backend-deployment.yaml` - Backend deployment (1 replica)
    - `backend-service.yaml` - Backend headless service for service discovery
    - `front-deployment.yaml` - Front deployment (1 replica)

## Architecture

```
+-------------------------------------------------------------+
|                        Kubernetes                           |
|                                                             |
|  +------------------+         +------------------+          |
|  |      Front       |         |     Backend      |          |
|  |   Deployment     |         |   Deployment     |          |
|  |   (1 replica)    |         |   (1 replica)    |          |
|  +------------------+         +------------------+          |
|          |                            |                     |
|          |                            |                     |
|          v                            |                     |
|  +------------------+         +------------------+          |
|  |  Spring Cloud    |         | backend-service  |          |
|  |  LoadBalancer    |-------->|   (headless)     |          |
|  |   + K8s Client   |         | ClusterIP: None  |          |
|  +------------------+         +------------------+          |
|                                                             |
|  ServiceAccount: app-service-account                        |
|  Role: kubernetes-reader (list, watch, get on pods,         |
|        services, endpoints, endpointslices, etc.)           |
|                                                             |
+-------------------------------------------------------------+
```

## Version Details

| Component    | Spring Boot 4 (Issue) | Spring Boot 3 (Working) |
|--------------|-----------------------|-------------------------|
| Spring Boot  | 4.0.2                 | 3.5.10                  |
| Spring Cloud | 2025.1.1              | 2025.0.1                |
| Java         | 25                    | 25                      |
