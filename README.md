# Fleet GitOps Platform

A production-ready Kubernetes platform for managing robot fleets using GitOps principles.

## 🚀 Features

- **Multi-Site Management**: Deploy and manage fleets across multiple facilities
- **Zero-Downtime Updates**: Blue/green deployments with Argo Rollouts
- **GitOps Workflow**: Git as single source of truth with ArgoCD
- **Auto-Scaling**: Declarative fleet scaling via Git commits
- **Self-Healing**: Automatic drift correction
- **Security**: Non-root containers with security contexts

## 📁 Repository Structure

```text
fleet-gitops-platform/
├── services/           # Microservices source code
│   ├── robot/          # Robot telemetry service
│   └── monitor/        # Fleet monitoring API
├── helm/               # Helm chart for deployment
├── argocd/             # ArgoCD configurations
└── docs/               # Documentation
```
## 🏗️ Architecture Note

For demo clarity, we model robots as individual Deployments. In production, we'd use StatefulSets or dedicated controllers for robot workload management at scale.

## 🛠️ Quick Start

### Prerequisites
- Kubernetes cluster (1.28+)
- kubectl, helm, git, make
- Docker Hub account

### Deploy

```bash
# Create modern cluster
kind create cluster --image kindest/node:v1.30.2

# Build and push images
make build push

# Bootstrap ArgoCD and deploy fleet
make bootstrap-argocd

# Verify deployment
make verify

# Set up port forwards
make port-forward
```

### Scale a Fleet
Edit helm/values-site-a.yaml:
```yaml
robots:
  count: 20  # Was 3
```

Commit and push:
```bash
git add helm/values-site-a.yaml
git commit -m "Scale Site A to 20 robots"
git push
```

ArgoCD automatically syncs the change.

### 📊 Monitoring
Access fleet status:
```bash
# After running make port-forward
curl http://localhost:8001/fleet | jq  # Site A
curl http://localhost:8002/fleet | jq  # Site B
curl http://localhost:8003/fleet | jq  # Site C
```

### 🔒 Security

- Non-root containers (UID 1000)  
- Read-only root filesystem  
- Security contexts enforced  
- Resource limits defined  
- AppProject governance  

## 📝 License
MIT  

## 👤 Author
Fitz Doud - Fleet Platform Engineering
