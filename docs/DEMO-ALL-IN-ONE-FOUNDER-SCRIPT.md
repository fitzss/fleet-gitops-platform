# Fleet GitOps Platform — End‑to‑End Founder Demo (All‑in‑One Script)

**Audience:** FleetGlue founders (Docker‑first, exploring Kubernetes/Helm/Argo CD)  
**Duration:** 7–10 minutes (+2–3 min optional Rollouts)  
**Style:** Read‑through script with runnable commands and business framing

---

## Opening narrative (30–45s)

This walk‑through proves that one Git repository can control multiple robot facilities, that scaling a site is a single commit, that unauthorized changes auto‑correct, and that updates ship with zero downtime. It maps directly to FleetGlue’s goals: reduce deployment cost and time, run different robot brands behind one pane of glass, and eliminate risky manual operations with a repeatable, auditable pipeline.

**Business outcomes framed up front:** faster deployments, fewer hardware/ops errors through automation, vendor‑agnostic control, immediate rollback, and real‑time fleet visibility.

---

## TL;DR quick path (for a new machine)

```bash
# 1) Install tools (Docker/kubectl/kind/helm/make/jq)
# 2) kind create cluster --name fleet-demo --image kindest/node:v1.30.2
# 3) make bootstrap-argocd
# 4) make founder-demo
```

Public images used by the chart:  
- `docker.io/fitzdoud/fleet-robot:v1`  
- `docker.io/fitzdoud/fleet-monitor:v1`  
No local `make build` / `make push` is required on other machines.

---

## One‑time host setup (Ubuntu / WSL)

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

## First‑time cluster + platform bootstrap

```bash
# 1) Clone repo
git clone https://github.com/fitzss/fleet-gitops-platform.git
cd fleet-gitops-platform

# 2) Create a Kubernetes‑in‑Docker cluster
kind create cluster --name fleet-demo --image kindest/node:v1.30.2

# 3) Install Argo CD + the apps (uses public images)
make bootstrap-argocd

# 4) Wait for apps to sync (until all three are Synced/Healthy)
kubectl get applications -n argocd -w
```

**Why this matters for FleetGlue:** this is the “walking skeleton” that mirrors how customers roll out to real sites later. Everything is declarative and automated from the start, which reduces time‑to‑value and support load.

---

## Two‑minute context warm‑up (before the live flow)

```bash
# Cluster identity
kubectl cluster-info
kubectl get nodes -o wide
```
A fresh Kind cluster with a single control‑plane node keeps the demo crisp while still exercising all the GitOps machinery.

```bash
# Facilities = namespaces
kubectl get ns | grep fleet-site
```
Three facilities are modeled as namespaces: A, B, and C. This maps to the mental model of “site per namespace or per cluster,” both of which FleetGlue can support at customer scale.

```bash
# GitOps control plane state
kubectl get applications -n argocd
```
All sites are Healthy and Synced to the exact Git commit—no hidden snowflake changes.

```bash
# Which Git commit is running (credibility)
for app in fleet-site-a fleet-site-b fleet-site-c; do
  rev=$(kubectl -n argocd get application $app -o jsonpath='{.status.sync.revision}')
  echo "$app -> $rev"
done
```
Those SHAs prove the live cluster matches the repository—compliance, auditability, and easy for FleetGlue to present to enterprise buyers.

```bash
# Inventory per site
kubectl get deploy,svc -n fleet-site-a
kubectl get deploy,svc -n fleet-site-b
kubectl get deploy,svc -n fleet-site-c
```
Each site has a monitor service plus **N** robot deployments (A=3, B=5, C=10 by default). Simple on purpose: “robots” are placeholders for any vendor container or adapter FleetGlue onboards.

```bash
# Quick robot counts (sanity vs. values files)
for ns in fleet-site-a fleet-site-b fleet-site-c; do
  echo -n "$ns robots: "
  kubectl get deploy -n $ns --no-headers | awk '$1 ~ /^robot-/{count++} END{print (count?count:0)}'
done
```

```bash
# Pods + IPs (one site deep-dive)
kubectl get pods -n fleet-site-a -o wide
```
All pods are Running; the monitor is exposed internally on port 8000. We will port‑forward in a moment for the REST/metrics view.

---

## Founder demo — UI‑first, business‑centric flow

### Pre‑demo prep (2 minutes prior)

```bash
# One command to set port‑forwards + print URLs
make founder-demo
```
Open **Argo CD UI** at `https://localhost:8080` (admin / password printed). Set Auto‑Refresh to 10 seconds and keep the terminal visible.

### 1) Single pane of glass (≈30s)

In the Applications view, the three cards `fleet-site-a`, `fleet-site-b`, `fleet-site-c` are green. Tree View for `fleet-site-a` shows one monitor + three robot deployments.  
**Message:** one Git repo defines every facility; the control plane scales to hundreds of sites without re‑inventing deployment for each vendor or location.

### 2) Scale a facility via Git (≈2–3 min)

**UI option (GitHub):** edit `helm/values-site-a.yaml` and change `count: 3` → `count: 10`, commit “Scale Site A to 10 robots for increased capacity”.  
**Terminal option:**

```bash
make demo-scale
# or
sed -i 's/count: 3/count: 10/' helm/values-site-a.yaml
git commit -am "Scale Site A to 10 robots" && git push
```

**What unfolds:** on the Argo CD card: **Synced → OutOfSync → Progressing → Synced**. The Site A Tree View fills with `robot-3 … robot-9` as the controller reconciles the desired state.  
**Message:** scaling is a reviewed commit, not a shell session. That lowers risk, preserves history, and enables change approvals—exactly the governance customers expect.

### 3) Self‑healing / drift correction (≈1 min)

```bash
# Manual “break” to simulate human error
kubectl scale deploy robot-0 -n fleet-site-a --replicas=5

# Verify auto-correction
sleep 10
kubectl get deploy robot-0 -n fleet-site-a -o jsonpath='{.spec.replicas}'
# Expected: 1
```
**What unfolds:** the app briefly shows OutOfSync, then snaps back to Synced.  
**Message:** the platform repairs unauthorized changes to match Git. This prevents snowflake clusters and hard‑to‑debug outages; it also supports audit requirements in manufacturing/logistics.

### 4) Real‑time fleet telemetry (≈1 min)

Port‑forwards are active from `make founder-demo`. Query the APIs:

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
**Message:** robot adapters push telemetry; the monitor aggregates JSON and Prometheus metrics. Vendor‑agnostic by design—swap images per vendor, keep the same GitOps control plane and dashboards.

### 5) Zero‑downtime update (optional, ≈2–3 min)

```bash
# Install Rollouts controller if needed
kubectl get crd rollouts.argoproj.io >/dev/null 2>&1 || make rollouts

# Build & push a v2 monitor (optional if you want to show an image bump you own)
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
**Observation:** in `fleet-site-a`, the Rollout shows blue/green while the service remains up.  
**Proof loop:**

```bash
while true; do 
  curl -sf http://localhost:8001/health && echo " ✓ Service UP"
  sleep 1
done
```
**Message:** updates land without interrupting operations—critical for live floors and 24/7 logistics.

### 6) Instant rollback (≈30s)

**UI:** `fleet-site-a → History →` select prior revision → **Rollback**.  
**Terminal:**

```bash
git revert HEAD --no-edit && git push
```
**Message:** recovery is a commit, not a firefight. This reduces MTTR and increases confidence to ship.

---

## Why this approach fits FleetGlue’s customers

- **Heterogeneous fleets, one control lane.** Each robot vendor runs in a container or adapter; Helm + ApplicationSet turns one template into per‑site deployments.  
- **Environment pipelines over ad‑hoc ops.** Changes flow as Pull Requests with automated checks. Argo CD reconciles clusters to Git; drift is detected and fixed.  
- **Security and compliance built‑in.** Non‑root containers, read‑only filesystems, scoped RBAC, and Git as the audit trail.  
- **Scales from pilot to portfolio.** The same repo pattern works for 1 site or 100+, 3 robots or 3,000. Add clusters as scale or latency demands grow.

---

## Environment pipelines (tie‑in for CTO/buyer language)

Environment Pipelines deploy software artifacts to live environments without teams touching clusters directly. Each environment’s config lives in Git as the source of truth; Argo CD keeps clusters aligned and prevents drift. Upgrades and rollbacks are Pull Requests and commits. This demo’s steps mirror that pipeline:
1. **Propose** a change (robot count, image version).  
2. **Review/Approve** via PR.  
3. **Merge → Reconcile** automatically across target environments.  
4. **Validate** via health, metrics, and SLOs.  
5. **Rollback** by reverting the commit if needed.

Benefits: fewer misconfigs, auditable history, safer handoffs between teams, and automation rather than manual access to production.

---

## Cloud‑native challenges we’ve already addressed

- **Local vs remote clusters:** this uses Kind for speed but keeps the same GitOps workflow that translates to cloud clusters later.  
- **Packaging & distribution:** Helm standardizes how we install and configure—one chart, many sites.  
- **Knowing what exists:** the warm‑up inventory and Tree View make resources visible before changes land.  
- **Resilience basics:** we show scaling, multiple replicas across robots, and recovery mechanisms.  
- **Walking skeleton:** this repo is a minimal end‑to‑end slice to try ideas safely, then grow.

---

## Numbers to call out live (tune to what happens)

- **Site A robots:** 3 → **10** after the commit.  
- **Downtime during rollout:** 0 failed health checks.  
- **Self‑healing correction time:** ≈10 seconds back to desired state.

---

## Executive Q&A (ready responses)

**How does this compare to “SSH and scripts”?**  
Git holds the desired state; Argo CD applies and maintains it. Changes are reviewed, reversible, and consistent across sites—no bespoke scripts or snowflake clusters.

**Can it handle multiple robot vendors and stacks?**  
Yes. Each vendor is an image or adapter behind a stable API/metrics contract. The GitOps control plane and the observability surface remain the same.

**On‑prem and cloud?**  
Both. Argo CD manages multiple clusters; the repo structure and charts don’t change.

**Security posture?**  
Non‑root containers, read‑only rootfs, resource limits, and AppProject guardrails; Git provides the audit trail for every change.

**Time to first value?**  
Hours for the platform; per‑vendor adapters depend on their APIs/SDKs, usually days—not months.

---

## Emergency fixes (keep handy)

```bash
# If Argo CD won’t sync
kubectl -n argocd patch application fleet-site-a --type merge -p '{"operation": {"sync": {"force": true}}}'

# If port‑forwards died
make port-forward

# Reset to a clean demo baseline
make demo-reset
```

---

## Post‑demo cleanup

```bash
make demo-reset
# Resets Git state, kills port-forwards, restores defaults
```

---

## Nice extras (use on request)

```bash
# Template → resource labels
kubectl get deploy -n fleet-site-a --show-labels

# Monitor service + endpoints
kubectl -n fleet-site-a get svc fleet-monitor
kubectl -n fleet-site-a get endpoints fleet-monitor

# ApplicationSet & AppProject wiring (fan-out & guardrails)
kubectl -n argocd get applicationset fleet-platform -o yaml | head -n 40
kubectl -n argocd get appprojects fleet-platform -o yaml | head -n 40
```

---

## Close (one-liner)

Pilot with one vendor adapter, keep this Git‑driven workflow, and scale out to more facilities—same control plane, faster deployments, lower risk, and clear business value.
