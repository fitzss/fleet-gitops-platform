# Minimal Host Setup & Bootstrap (Ubuntu)

Here’s the minimal, copy-paste path that will work for anyone using your public images (`fitzdoud/fleet-*`):

---

## One-time host setup (Ubuntu)

```bash
# System deps (Docker + tooling)
sudo apt update && sudo apt install -y docker.io make git curl jq

# Let your user run docker without sudo (log out/in afterwards or run newgrp)
sudo usermod -aG docker $USER
newgrp docker

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# kind
curl -Lo kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64
chmod +x kind && sudo mv kind /usr/local/bin/

# helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

---

## First-time cluster + platform bootstrap

```bash
# 1) Clone repo
git clone https://github.com/fitzss/fleet-gitops-platform.git
cd fleet-gitops-platform

# 2) Create a Kubernetes-in-Docker cluster
kind create cluster --name fleet-demo --image kindest/node:v1.30.2

# 3) Install Argo CD + the apps (uses your public images, no Docker Hub login needed)
make bootstrap-argocd

# 4) Wait for apps to sync (watch until all three are Synced/Healthy)
kubectl get applications -n argocd -w
```

---

## Start the demo (your existing targets)

```bash
# Set up port-forwards + print URLs
make founder-demo

# …then follow your Founder Demo flow
make founder-scale           # scale site A via Git
kubectl scale deploy robot-0 -n fleet-site-a --replicas=5  # drift demo
make founder-status          # quick fleet status
```

---

## Why this is needed

- `make founder-demo` → only does port-forwards + prints URLs. It assumes a cluster and Argo CD are already up with your Applications created.
- `make bootstrap-argocd` → actually installs Argo CD and your ApplicationSet/AppProject. This is the step a new machine needs before any demo commands.
- You don’t need to `make build`/`make push` on other people’s machines because your Helm values reference public images (`docker.io/fitzdoud/fleet-robot:v1` and `docker.io/fitzdoud/fleet-monitor:v1`). The cluster will pull those by default.

---

## TL;DR

For a totally new Ubuntu machine:

- Install tools (Docker/kubectl/kind/helm/make/jq)
- kind create cluster …
- make bootstrap-argocd
- make founder-demo

After that, all your Founder Demo steps will work as-is.
