# Fleet GitOps Platform — End‑to‑End Founder Demo (All‑in‑One Script, Deep Dive)

**Audience:** FleetGlue founders (Docker‑first, exploring Kubernetes/Helm/Argo CD)  
**Duration:** 7–10 minutes (+2–3 min optional Rollouts)  
**Style:** Read‑through script with runnable commands, *business framing first*, and technical depth where it matters.

---

## Why this demo matters (framing, 45–60s)

This demonstration shows a repeatable way to operate a heterogeneous robot fleet with **one Git repository** as the control plane. With a single commit, we can scale a facility, heal unauthorized changes, and deliver zero‑downtime updates. This lines up with FleetGlue’s mission: *deploy faster, integrate multiple robot brands, reduce manual ops and hardware errors, and give customers a single pane of glass.*

**Customer pain we are addressing (assumptions from FleetGlue positioning):**
- New robots and vendors introduce **fragmented tooling**; every site becomes a snowflake.
- **Manual deployments** are slow, error‑prone, and hard to audit or roll back.
- **Downtime** during updates is unacceptable on active floors.
- Leadership needs **proof of control** (who changed what, when, why) and **recovery** (one‑click rollback).

**Outcomes to highlight:**
- 3× faster deployments → change is a reviewed commit, not a long runbook.
- 70% fewer errors → drift auto‑corrects, changes are templated and auditable.
- Vendor‑agnostic control plane → swap robot images/adapters, keep the same pipeline.
- Zero‑downtime updates → Argo Rollouts gates promotion on health.
- Immediate rollback → revert the commit, system reconciles safely.

---

## TL;DR quick path (for a new machine)

```bash
# 1) Install tools (Docker/kubectl/kind/helm/make/jq)
# 2) kind create cluster --name fleet-demo --image kindest/node:v1.30.2
# 3) make bootstrap-argocd
# 4) make founder-demo
```

Public images the chart pulls:  
- `docker.io/fitzdoud/fleet-robot:v1`  
- `docker.io/fitzdoud/fleet-monitor:v1`  
No local `make build` / `make push` required on other machines.

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

**Business translation:** This is the **environment pipeline**. Environments are declared in Git and reconciled automatically. Teams stop touching clusters directly; instead they open pull requests that are validated, rolled out, and rolled back safely.

---

## Two‑minute context warm‑up (pre‑demo posture)

```bash
# Cluster identity
kubectl cluster-info
kubectl get nodes -o wide
```
A fresh Kind cluster (single control‑plane) keeps the demo quick and deterministic, while exercising the full GitOps workflow we’d use in a customer’s real clusters.

```bash
# Facilities = namespaces
kubectl get ns | grep fleet-site
```
Three facilities map to namespaces **A/B/C**. The same pattern can be “namespace per site” (single cluster) or “cluster per site” (multi‑cluster). Both work with Argo CD.

```bash
# GitOps control plane state
kubectl get applications -n argocd
```
All sites show **Synced/Healthy**. The cluster is not trusted on its own—Git is the source of truth and Argo CD enforces it.

```bash
# Which Git commit is running (credibility)
for app in fleet-site-a fleet-site-b fleet-site-c; do
  rev=$(kubectl -n argocd get application $app -o jsonpath='{.status.sync.revision}')
  echo "$app -> $rev"
done
```
These commit SHAs are the **evidence** of compliance: “what’s running equals what’s in Git.”

```bash
# Inventory per site
kubectl get deploy,svc -n fleet-site-a
kubectl get deploy,svc -n fleet-site-b
kubectl get deploy,svc -n fleet-site-c
```
Each site runs a **monitor** service and **N** robot deployments (A=3, B=5, C=10 default). Robots are **placeholders for vendor containers/adapters**—swap images, keep the control plane.

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
Pods are Running; the monitor is a ClusterIP on port 8000. We will port‑forward to reach the REST/metrics APIs.

---

## Founder demo — UI‑first, business‑centric flow

### Pre‑demo prep (2 minutes prior)

```bash
# One command to set port‑forwards + print URLs
make founder-demo
```
Argo CD UI `https://localhost:8080` (admin / password from the command). Set auto‑refresh to 10s. Keep your terminal visible for the API proof points.

---

### 1) Single pane of glass (≈30s)

**What to show:** In Argo CD → Applications, three green cards `fleet-site-a/b/c`. Click **fleet-site-a → Tree** to reveal one monitor + three robot deployments.  
**Message:** One repo templatizes *every* facility. The same workflow scales to hundreds of sites and multiple vendors without bespoke scripts or snowflake clusters.

**Why buyers care:** Lower **time‑to‑deploy** for new facilities; standardization reduces **support load** and **training cost**.

---

### 2) Scale a facility via Git (≈2–3 min)

**GitHub UI path:** edit `helm/values-site-a.yaml`, change `count: 3` → `count: 10`, commit “Scale Site A to 10 robots for increased capacity”.  
**Terminal path:**

```bash
make demo-scale
# or
sed -i 's/count: 3/count: 10/' helm/values-site-a.yaml
git commit -am "Scale Site A to 10 robots" && git push
```

**What unfolds in Argo CD:** the **fleet-site-a** card transitions **Synced → OutOfSync → Progressing → Synced**; Tree view shows `robot-3 … robot-9` appearing as reconciliation proceeds.

**Business translation:** Scaling is a **reviewable commit**, not a risky shell session. It leaves an audit trail, enables approvals, and is reversible. This is how to achieve **3× faster deployments** with **fewer mistakes**.

**If timing lags:** force a refresh safely:
```bash
kubectl -n argocd annotate application fleet-site-a argocd.argoproj.io/refresh=hard --overwrite
```

---

### 3) Self‑healing / drift correction (≈1 min)

Simulate human error to prove guardrails:

```bash
kubectl scale deploy robot-0 -n fleet-site-a --replicas=5
sleep 10
kubectl get deploy robot-0 -n fleet-site-a -o jsonpath='{.spec.replicas}'
# Expected: 1
```
**What happens:** the app briefly shows OutOfSync, then Argo CD **repairs** state back to Git (replicas=1).

**Business translation:** This kills **snowflake drift** and “mystery fixes.” It’s also a compliance story: production reflects Git; unauthorized changes are corrected and visible.

**If it doesn’t auto‑heal (rare):**
```bash
kubectl -n argocd get application fleet-site-a -o yaml | grep -A3 syncPolicy
kubectl -n argocd patch application fleet-site-a --type merge -p '{"operation": {"sync": {}}}'
```

---

### 4) Real‑time fleet telemetry (≈1 min)

Port‑forwards are live from `make founder-demo`. Prove status and metrics:

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
**Business translation:** Vendor‑agnostic **APIs and metrics**. Swap robot images/adapters without changing the control plane or dashboards. This aligns with “single pane of glass” claims.

---

### 5) Zero‑downtime update (optional, ≈2–3 min)

```bash
# Ensure Rollouts controller exists
kubectl get crd rollouts.argoproj.io >/dev/null 2>&1 || make rollouts

# (Optional) Build & push a v2 of the monitor you control
docker build -t fitzdoud/fleet-monitor:v2 services/monitor
docker push fitzdoud/fleet-monitor:v2

# Switch to Rollout + v2 via Git
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

**What to watch:** In `fleet-site-a`, the **Rollout** object gradually shifts traffic while health checks hold the line.

**Prove zero downtime:**
```bash
while true; do 
  curl -sf http://localhost:8001/health && echo " ✓ Service UP"
  sleep 1
done
```
**Business translation:** **No interrupted active deployments.** Updates are gated and safe to promote. This is critical for live floors and on‑time SLAs.

---

### 6) Instant rollback (≈30s)

**UI:** `fleet-site-a → History` → select prior revision → **Rollback**.  
**Terminal:**

```bash
git revert HEAD --no-edit && git push
```
**Business translation:** Recovery is a **commit**, not a firefight. Lower MTTR, higher confidence, safer change velocity.

---

## Why this approach fits FleetGlue’s customers

- **Heterogeneous fleets, one control lane.** Robot vendors become images/adapters. Helm + ApplicationSet fans out per‑site configs.  
- **Environment pipelines replace ad‑hoc ops.** PRs drive change; Argo CD reconciles; drift is detected and fixed.  
- **Security & compliance built‑in.** Non‑root containers, read‑only rootfs, RBAC/AppProject guardrails; Git is the audit trail.  
- **Scales from pilot to portfolio.** One repo pattern works for 1 or 100+ sites, 3 or 3,000 robots. Multi‑cluster is first‑class.

**Near‑term add‑ons for FleetGlue (roadmap signal):**
- Policy gates (e.g., OPA/Conftest) to block risky chart changes.  
- Metrics‑driven rollouts (promote only if SLOs hold).  
- Per‑vendor adapters standardizing telemetry/commands into a common API.  
- Secrets management (SOPS/External Secrets) for production readiness.

---

## Environment pipelines (exec language)

1) **Propose**: bump robot count or image version.  
2) **Review**: automated checks + human approval.  
3) **Merge → Reconcile**: Argo CD applies to the target sites.  
4) **Validate**: health, metrics, SLOs, dashboards.  
5) **Rollback**: revert the commit if needed.

**Benefits:** fewer misconfigs, auditable history, safer handoffs, zero ad‑hoc shell into prod.

---

## Cloud‑native challenges addressed (talk track)

- **Local vs remote clusters:** demo uses Kind for speed; workflow is identical on EKS/GKE/AKS/on‑prem.  
- **Packaging & distribution:** Helm standardizes installation + configuration; ApplicationSet scales it.  
- **Visibility:** inventory + Argo tree view provides “what exists” before you change anything.  
- **Resilience:** replicas, healing, and progressive delivery are first‑class.  
- **Walking skeleton:** minimal end‑to‑end slice to test integrations and evolve safely.

---

## Numbers to call out (tune to live results)

- Site A robots: 3 → **10** after commit.  
- Rollout downtime: **0** failed health checks.  
- Self‑healing: ~**10s** to revert unauthorized scale change.

---

## Executive Q&A (fast answers)

**How is this better than SSH + scripts?** Git is the desired state; Argo CD applies and maintains it. Changes are reviewed, auditable, reversible, and consistent across sites.

**Multiple robot vendors and stacks?** Yes—each is an image/adapter behind stable APIs/metrics. Control plane stays the same.

**On‑prem and cloud?** Both—multi‑cluster is first‑class.

**Security posture?** Non‑root containers, read‑only rootfs, resource limits, RBAC guardrails; Git is the audit trail.

**Time to first value?** Hours for the platform; per‑vendor integrations typically days (depends on SDKs/APIs).

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

## Close (one‑liner)

Pilot with one vendor adapter using this Git‑driven pipeline, then scale to more sites. Same control plane, faster deployments, lower risk, and business value you can prove on a dashboard.
