# Fleet GitOps Platform — End-to-End Demo (All-in-One)

**Audience:** FleetGlue founders (Docker-first, exploring Kubernetes/Helm/Argo CD)  
**Duration:** 7–10 minutes (plus 2–3 min optional Rollouts)  
**Focus:** Business outcomes, visual UI, minimal jargon

---

## TL;DR (Quick Path)

```bash
# New machine quick path:
# 1) Install tools (Docker/kubectl/kind/helm/make/jq)
# 2) kind create cluster ...
# 3) make bootstrap-argocd
# 4) make founder-demo
```

> This uses public images:
> - `docker.io/fitzdoud/fleet-robot:v1`
> - `docker.io/fitzdoud/fleet-monitor:v1`  
> No `make build` / `make push` needed on other machines.

---

## One-Time Host Setup (Ubuntu / WSL)

```bash
# System deps (Docker + tooling)
sudo apt update && sudo apt install -y docker.io make git curl jq

# Allow your user to run Docker without sudo (open a new shell afterwards)
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

## First-Time Cluster + Platform Bootstrap

```bash
# 1) Clone repo
git clone https://github.com/fitzss/fleet-gitops-platform.git
cd fleet-gitops-platform

# 2) Create a Kubernetes-in-Docker cluster
kind create cluster --name fleet-demo --image kindest/node:v1.30.2

# 3) Install Argo CD + the apps (uses public images)
make bootstrap-argocd

# 4) Wait for apps to sync (until all three are Synced/Healthy)
kubectl get applications -n argocd -w
```

---

## 2-Minute Context Warm-Up (before the main demo)

```bash
# 0) Cluster identity
kubectl cluster-info
kubectl get nodes -o wide
# Say: "Fresh Kind cluster—single control-plane node for this demo."
```

```bash
# 1) Facilities = namespaces
kubectl get ns | grep fleet-site
# Say: "Three facilities modeled as namespaces: A, B, C."
```

```bash
# 2) GitOps control plane status
kubectl get applications -n argocd
# Say: "Argo CD synced all three sites—Healthy and in lock-step with Git."
```

```bash
# 3) Which Git commit is running (credibility touch)
for app in fleet-site-a fleet-site-b fleet-site-c; do
  rev=$(kubectl -n argocd get application $app -o jsonpath='{.status.sync.revision}')
  echo "$app -> $rev"
done
# Say: "These SHAs are the exact Git commits deployed per site."
```

```bash
# 4) Inventory per site
kubectl get deploy,svc -n fleet-site-a
kubectl get deploy,svc -n fleet-site-b
kubectl get deploy,svc -n fleet-site-c
# Say: "Each site has a monitor + N robot deployments (A=3, B=5, C=10 by default)."
```

```bash
# 5) Quick robot counts (must match values files)
for ns in fleet-site-a fleet-site-b fleet-site-c; do
  echo -n "$ns robots: "
  kubectl get deploy -n $ns --no-headers | awk '$1 ~ /^robot-/{count++} END{print (count?count:0)}'
done
# Say: "Counts line up with the Git-defined desired state."
```

```bash
# 6) One namespace deep-dive (pods + IPs)
kubectl get pods -n fleet-site-a -o wide
# Say: "All pods Running; monitor exposed internally on 8000."
```

```bash
# 7) (Optional) Recent events
kubectl get events -n fleet-site-a --sort-by=.lastTimestamp | tail -n 10
# Say: "No recent errors—clean baseline before we scale."
```

> **Transition:** “You’ve seen the cluster shape and that Argo CD is in control. Now let’s watch it visually while we scale with a Git commit.”

---

## Founder Demo — Flow (UI-first, business-centric)

### Pre-Demo (2 minutes before the call)

```bash
# One command to set port-forwards + print URLs
make founder-demo
```

- Open **Argo CD UI**: https://localhost:8080  
  Login: `admin` / *(password printed by the command above)*  
- Set Auto-Refresh to **10 seconds** (top-right).  
- Arrange windows: Argo CD main screen, terminal side-by-side.

---

### 1) Single Pane of Glass (30s)

**In Argo CD UI**
- Show Applications view: `fleet-site-a`, `fleet-site-b`, `fleet-site-c` (all green).
- Click **fleet-site-a → Tree View** to reveal monitor + robot deployments.

**Say:**  
“This is your fleet control center. Each card is a facility. All managed from one Git repository. This scales to hundreds of sites with the same template.”

---

### 2) Scale a Facility via Git (2–3 min)

**Option A (UI, recommended):**
- GitHub → `helm/values-site-a.yaml` → Edit → `count: 3` → `count: 10`  
- Commit: “Scale Site A to 10 robots for increased capacity”

**Option B (terminal):**
```bash
make demo-scale
# or
sed -i 's/count: 3/count: 10/' helm/values-site-a.yaml
git commit -am "Scale Site A to 10 robots" && git push
```

**Watch in Argo CD UI**
- `Synced → OutOfSync → Progressing → Synced`
- Tree view fills with `robot-3 ... robot-9`

**Say:**  
“We just scaled from 3 to 10 robots with one Git commit. No kubectl or manual ops. Every change is auditable and instantly reversible—exactly how you get 3× faster deployments.”

---

### 3) Self-Healing / Drift Correction (1 min)

**Induce drift:**
```bash
kubectl scale deploy robot-0 -n fleet-site-a --replicas=5
```

**Observe:**
- Argo CD briefly OutOfSync → back to Synced  
- Verify:
```bash
kubectl get deploy robot-0 -n fleet-site-a -o jsonpath='{.spec.replicas}'
# Expected: 1
```

**Say:**  
“If someone changes production by hand, Argo CD detects drift and repairs it to match Git. No snowflake environments; much lower ops risk.”

---

### 4) Real-Time Fleet Telemetry (1 min)

Port-forwards are already set by `make founder-demo`. Query the APIs:

```bash
# Health and fleet snapshot
curl -s http://localhost:8001/health | jq
curl -s http://localhost:8001/fleet | jq '{
  total_robots: .total_robots,
  operational: .operational,
  low_battery: .low_battery
}'

# Compare sites
echo "=== Robot Count Per Site ==="
echo "Site A: $(curl -s localhost:8001/fleet | jq -r .total_robots) robots"
echo "Site B: $(curl -s localhost:8002/fleet | jq -r .total_robots) robots"
echo "Site C: $(curl -s localhost:8003/fleet | jq -r .total_robots) robots"

# Prometheus metrics (Grafana-ready)
curl -s http://localhost:8001/metrics | head -5
```

**Say:**  
“Robots post telemetry; the monitor aggregates and exposes JSON + Prometheus metrics. It’s vendor-agnostic—swap any robot container, keep the same control plane.”

---

### 5) Zero-Downtime Update (Optional, 2–3 min)

```bash
# Ensure Rollouts is installed (once per cluster)
kubectl get crd rollouts.argoproj.io >/dev/null 2>&1 || make rollouts

# Build & push a v2 monitor (only needed if you want your own v2)
docker build -t fitzdoud/fleet-monitor:v2 services/monitor
docker push fitzdoud/fleet-monitor:v2

# Flip to Rollout + v2 via Git
cat > helm/values-gitops.yaml <<'YAML'
monitor:
  image: docker.io/fitzdoud/fleet-monitor:v2
robots:
  image: docker.io/fitzdoud/fleet-robot:v1
rollout:
  enabled: true
YAML

git add helm/values-gitops.yaml
git commit -m "Deploy monitor v2 with blue/green rollout"
git push
```

**Observe in UI:**  
`fleet-site-a → fleet-monitor` Rollout shows blue/green.

**Prove zero downtime:**
```bash
while true; do 
  curl -sf http://localhost:8001/health && echo " ✓ Service UP"
  sleep 1
done
```

**Say:**  
“The old version serves traffic while the new one is verified. Zero downtime—critical for operations.”

---

### 6) Instant Rollback (30s)

**In Argo CD UI:** `fleet-site-a → History` → pick previous revision → **Rollback**  
**Or terminal:**
```bash
git revert HEAD --no-edit && git push
```

**Say:**  
“Any change can be instantly rolled back. Full audit trail, complete reversibility.”

---

## Emergency Fixes

```bash
# If Argo CD won’t sync
kubectl -n argocd patch application fleet-site-a   --type merge -p '{"operation": {"sync": {"force": true}}}'

# If port-forwards died
make port-forward

# Reset everything to a clean demo state
make demo-reset
```

---

## Post-Demo Cleanup

```bash
make demo-reset
# Resets Git state, kills port-forwards, restores defaults
```

---

## Nice Extras (on request)

```bash
# Template → resource labels
kubectl get deploy -n fleet-site-a --show-labels

# Monitor service + endpoints
kubectl -n fleet-site-a get svc fleet-monitor
kubectl -n fleet-site-a get endpoints fleet-monitor

# ApplicationSet & AppProject wiring (guardrails & fan-out)
kubectl -n argocd get applicationset fleet-platform -o yaml | head -n 40
kubectl -n argocd get appprojects fleet-platform -o yaml | head -n 40
```

**Avoid** unless prepped:
- `kubectl top` (needs metrics-server on Kind)
- `kubectl argo rollouts ...` plugin (unless installed)
- Long log tailing (save for troubleshooting)

---
