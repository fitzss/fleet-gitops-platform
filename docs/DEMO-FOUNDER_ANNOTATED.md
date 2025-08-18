# Fleet GitOps Platform — Founder Demo (Annotated Presenter Notes)

**Audience:** FleetGlue founders (Docker-first; exploring Kubernetes/Helm/Argo CD)  
**Duration:** 7–10 minutes (+2 min context warm‑up)  
**Goal:** Show a repeatable, auditable way to deploy, scale, and operate fleets *faster* and with *fewer errors*, using Git as the control plane.

---

## 0) Problem Framing — FleetGlue’s world (30–45s)

> **Say:** “I framed this demo around what FleetGlue promises customers today—fast deployments, one pane of glass, zero downtime, and vendor independence—and I’ll show a concrete, working path to deliver that at scale.”

**Observed needs (from FleetGlue positioning):**
- **Speed to deploy:** Add robots and sites quickly without bespoke scripts per customer.
- **Single pane of glass:** Clear visibility across facilities, minimal operator ceremony.
- **No disruption:** Upgrades without taking production down.
- **Vendor independence:** Abstract robot vendor differences; standardize orchestration.
- **Auditability & safety:** Everything traceable and reversible (critical in manufacturing).

**What this demo proves:** A **GitOps control plane** that maps directly to these outcomes. One repo → many sites, scale via commits, self-heal drift, real-time telemetry, optional zero-downtime releases.

---

## 1) Two-Minute Context Warm-Up (before the main demo)

> **Purpose:** Quickly establish the cluster shape and “who is in control” so the UI demo lands immediately.

### Commands (run selectively)
```bash
# Who am I talking to? (cluster identity)
kubectl cluster-info
kubectl get nodes -o wide

# Which namespaces represent sites?
kubectl get ns | grep fleet-site

# GitOps control plane status (Argo CD Applications)
kubectl get applications -n argocd

# What commit is actually deployed at each site?
for app in fleet-site-a fleet-site-b fleet-site-c; do
  rev=$(kubectl -n argocd get application $app -o jsonpath='{.status.sync.revision}')
  echo "$app -> $rev"
done

# Inventory per site (deployments + services)
kubectl get deploy,svc -n fleet-site-a
kubectl get deploy,svc -n fleet-site-b
kubectl get deploy,svc -n fleet-site-c
```

**What’s happening / Why it matters (say snippets):**
- “Three **namespaces = three facilities**. It scales linearly with customers.”
- “**Argo CD is synced/healthy** → Git is the source of truth; no snowflake envs.”
- “These **SHAs are the exact Git commits** currently running—strong auditability.”

---

## 2) Opening — Single Pane of Glass (Argo CD UI, ~45s)

**What to do:**  
Open **Argo CD Applications**. Point at the three green cards: `fleet-site-a`, `fleet-site-b`, `fleet-site-c`. Click **Site A → Tree** view.

**What you’re showing (translate to business):**
- One Git repo **fans out** to many facilities with **consistent templates**.
- “This is your **fleet control center**—status, history, and one-click rollback.”

**Under the hood (1 sentence):** ApplicationSet + Helm render the same chart with site‑specific values to each namespace.

**Proof points to call out:**
- Status = **Synced/Healthy** on all sites.
- Tree view shows **monitor + N robot deployments** (A=3, B=5, C=10 default).

---

## 3) Scale a Facility via Git (2–3 min)

> **Say:** “We scale with a **Git commit**, not cluster commands. That gives change control, code review, and instant rollback.”

### Option A: GitHub UI (recommended for founders)
- Navigate to `helm/values-site-a.yaml`
- Edit `count: 3` → `count: 10`
- Commit: `“Scale Site A to 10 robots for increased capacity”`

### Option B: Terminal
```bash
sed -i 's/count: 3/count: 10/' helm/values-site-a.yaml
git commit -am "Scale Site A to 10 robots" && git push
```

**What to watch (UI):**  
`fleet-site-a` → **Synced (green) → OutOfSync (yellow) → Progressing (blue) → Synced (green)**. Tree view fills in `robot-3 … robot-9`.

**Under the hood:**  
Argo CD compares desired Git state to the cluster and **creates new Deployments**; Kubernetes schedules pods; readiness probes gate availability.

**Why it matters to FleetGlue (business effects):**
- **Speed:** 1 commit → 7 new robots, **no manual ops**.
- **Auditability:** Every change is **reviewable** and tied to a ticket/PR.
- **Repeatability:** Same workflow scales from **one site to hundreds**.

**If slow to sync:**  
```bash
kubectl -n argocd annotate application fleet-site-a \
  argocd.argoproj.io/refresh=hard --overwrite
```

---

## 4) Self-Healing / Drift Correction (1 min)

> **Say:** “If someone changes prod by hand, the platform **snaps it back** to what Git says.”

**Induce drift:**
```bash
kubectl scale deploy robot-0 -n fleet-site-a --replicas=5
```

**Watch:**  
Argo briefly shows **OutOfSync → Synced** as it **reconciles**. Then verify:
```bash
kubectl get deploy robot-0 -n fleet-site-a -o jsonpath='{.spec.replicas}'
# Expect: 1
```

**Under the hood:**  
Sync policy `automated.selfHeal: true` triggers reconciliation; declarative spec wins over imperative drift.

**Business impact:**  
- **Fewer production mistakes**; removes “works on my cluster” drama.
- **Lower MTTR** by making the **correct state obvious** (Git).

---

## 5) Real-Time Fleet Telemetry (1 min)

**Port-forward (if needed):**
```bash
kubectl -n fleet-site-a port-forward svc/fleet-monitor 8001:8000 >/dev/null 2>&1 &
kubectl -n fleet-site-b port-forward svc/fleet-monitor 8002:8000 >/dev/null 2>&1 &
kubectl -n fleet-site-c port-forward svc/fleet-monitor 8003:8000 >/dev/null 2>&1 &
sleep 2
```

**Query APIs:**
```bash
# Health
curl -s http://localhost:8001/health | jq

# Snapshot for Site A
curl -s http://localhost:8001/fleet | jq '{
  total_robots: .total_robots,
  operational: .operational,
  low_battery: .low_battery
}'

# Compare sites
for p in 8001 8002 8003; do
  echo "Port $p: $(curl -s localhost:$p/fleet | jq -r .total_robots) robots"
done

# Prometheus preview
curl -s http://localhost:8001/metrics | head -5
```

**What’s happening / Why it matters:**
- Robots publish simulated telemetry; **monitor aggregates** and exposes **JSON + Prometheus** → immediate **Grafana/alerts** integration.
- **Vendor agnostic**: swap robot images; **control plane stays the same**.

---

## 6) Zero‑Downtime Update (Optional, 2 min)

> **Say:** “We upgrade **without interruption**—critical for live production floors.”

**Pre-req (if not installed):**
```bash
kubectl get crd rollouts.argoproj.io >/dev/null 2>&1 || make rollouts
```

**Build & push a v2 (example):**
```bash
echo '# v2 enhancement' >> services/monitor/monitor.py
docker build -t fitzdoud/fleet-monitor:v2 services/monitor
docker push fitzdoud/fleet-monitor:v2
```

**Enable rollout + bump image via Git:**
```bash
cat > helm/values-gitops.yaml <<'YAML'
monitor:
  image: docker.io/fitzdoud/fleet-monitor:v2
robots:
  image: docker.io/fitzdoud/fleet-robot:v1
rollout:
  enabled: true
YAML

git add helm/values-gitops.yaml
git commit -m "Enable blue/green deployment to monitor v2"
git push
```

**Watch rollout + prove uptime:**
```bash
kubectl get rollout -n fleet-site-a fleet-monitor -w
# In a second terminal:
while true; do curl -sf http://localhost:8001/health && echo " ✓ Service UP"; sleep 1; done
```

**Why it matters:**  
- **No downtime** during upgrades → **no paused production**.  
- Supports **progressive delivery** (can gate on metrics/approvals).

---

## 7) Instant Rollback (30s)

**UI:** Argo CD → Site A → **History** → select previous revision → **Rollback**.  
**CLI alternative:**
```bash
git revert HEAD --no-edit && git push
```

**Business value:**  
- **Risk control**—any change can be **undone fast**.  
- Builds stakeholder trust for faster iteration.

---

## 8) Close — Map to FleetGlue Outcomes (30–45s)

- **“Deploy at the speed of light”** → Git push to prod in seconds (multi-site).  
- **“Single pane of glass”** → Argo CD Apps + Tree + History.  
- **“No interrupted deployments”** → Blue/green rollouts keep service up.  
- **“Reduce errors by 90%”** → GitOps eliminates manual, ad‑hoc steps.  
- **“Vendor independent”** → Swap images; orchestration stays constant.  

**Path to productization:**
1) Replace simulated robots with real vendor images (MiR/OTTO/Omron/…).
2) Standardize telemetry envelope (normalize fields; keep vendor‑specifics as extensions).
3) Add dashboards + SLO alerts (Grafana/Alertmanager or FleetGlue UI).
4) Harden supply chain (SBOM, cosign, policy checks) and RBAC multi‑tenancy.

---

## Appendix — Handy One-Liners

**Robot counts per site**
```bash
for ns in fleet-site-a fleet-site-b fleet-site-c; do
  echo -n "$ns: "
  kubectl get deploy -n "$ns" --no-headers | awk '$1 ~ /^robot-/{count++} END{print (count?count:0)}'
done
```

**Force re-sync a site**
```bash
kubectl -n argocd patch application fleet-site-a \
  --type merge -p '{"operation": {"sync": {"force": true}}}'
```

**Kill port-forwards (Linux/macOS)**
```bash
pkill -f "port-forward" || true
```

**Reset demo state**
```bash
make demo-reset
```
