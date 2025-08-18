#!/bin/bash
set -e
echo "=== Fleet GitOps Platform Bootstrap ==="
Check prerequisites
command -v docker >/dev/null 2>&1 || { echo "Docker required"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl required"; exit 1; }
command -v kind >/dev/null 2>&1 || { echo "kind required"; exit 1; }
Create cluster
echo "Creating Kind cluster..."
kind delete cluster --name fleet-demo 2>/dev/null || true
kind create cluster --name fleet-demo --image kindest/node:v1.30.2
Build and push
echo "Building images..."
make build
echo "Pushing to registry..."
make push
Deploy platform
echo "Installing ArgoCD..."
make bootstrap-argocd
echo "Waiting for sync..."
sleep 30
Verify
make verify
echo "=== Bootstrap Complete ==="
echo "Run: make port-forward"
echo "Then: make test-fleet"
