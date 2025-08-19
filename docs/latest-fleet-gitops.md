Fleet GitOps Platform — End-to-End Founder Demo (All-in-One Script, Deep Dive)
Demo Introduction (30–45s)

What this proves: With a single Git repository, I can operate a mixed-brand robot fleet across multiple sites. A single commit scales capacity, unauthorized changes are auto-corrected, and updates ship with zero downtime—all with full auditability and instant rollback.

Why it matters to FleetGlue: This demonstrates the machinery behind your promises—faster deployments, less downtime, vendor-agnostic control—delivered from day one, not just at scale (using GitOps, Helm, and Argo CD).

Customer pains I’m addressing:

Every new robot/vendor brings different tools, so each site drifts and becomes hard to support.

Manual, one-off deployments are slow, error-prone, and hard to audit or roll back.

Updates can’t interrupt active operations.

Leadership needs visibility: “who changed what, when, why,” plus safe, fast rollback.

Outcomes I will demonstrate live (not just claim):

Speed: Change is a reviewed Git commit, not a runbook.

Quality: Drift auto-corrects; changes are templated and auditable.

Vendor-agnostic: Swap robot images/adapters, keep the same pipeline.

Zero downtime: Progressive rollout gates promotion on health.

Instant recovery: Revert the commit; the system reconciles safely.

How to watch: Look for four proof points—(1) commit → scale up, (2) manual drift → auto-heal, (3) APIs/metrics live across sites, (4) update → zero downtime → rollback.

Transition: “With that frame, I’ll spin up the environment and show those four proof points end-to-end.”

TL;DR quick path (for a new machine)
# 1) Install tools (Docker/kubectl/kind/helm/make/jq)
# 2) kind create cluster --name fleet-demo --image kindest/node:v1.30.2
# 3) make bootstrap-argocd
# 4) make founder-demo


Public images the chart pulls:

docker.io/fitzdoud/fleet-robot:v1

docker.io/fitzdoud/fleet-monitor:v1
No local make build / make push required on other machines.

One-time host setup (Ubuntu / WSL)
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

First-time cluster + platform bootstrap
1) Clone repo
git clone https://github.com/fitzss/fleet-gitops-platform.git
cd fleet-gitops-platform


The repo is the product truth. Everything lives here, so changes are reviewable and reversible.

2) Create a Kubernetes-in-Docker cluster
kind create cluster --name fleet-demo --image kindest/node:v1.30.2


Kind spins up a disposable local cluster. Customers may use cloud/on-prem, but workflow stays identical.

3) Install Argo CD + the apps (uses public images)
make bootstrap-argocd


Argo CD installs and registers the apps. From now on, clusters follow Git—no hand edits.

4) Wait for apps to sync (until all three are Synced/Healthy)
kubectl get applications -n argocd -w


When apps show Synced/Healthy, we know cluster = Git. That’s our baseline.

Business translation: This is the environment pipeline. Environments are declared in Git and reconciled automatically. Teams stop touching clusters directly; instead they open pull requests that are validated, rolled out, and rolled back safely.

Two-minute context warm-up (pre-demo posture)
# Cluster identity
kubectl cluster-info
kubectl get nodes -o wide


A fresh Kind cluster (single control-plane) keeps the demo quick and deterministic, while exercising the full GitOps workflow we’d use in a customer’s real clusters.

# Facilities = namespaces
kubectl get ns | grep fleet-site


Three facilities map to namespaces A/B/C. The same pattern can be “namespace per site” (single cluster) or “cluster per site” (multi-cluster). Both work with Argo CD.

# GitOps control plane state
kubectl get applications -n argocd


All sites show Synced/Healthy. The cluster is not trusted on its own—Git is the source of truth and Argo CD enforces it.

# Which Git commit is running (credibility)
for app in fleet-site-a fleet-site-b fleet-site-c; do
  rev=$(kubectl -n argocd get application $app -o jsonpath='{.status.sync.revision}')
  echo "$app -> $rev"
done


These commit SHAs are the evidence of compliance: “what’s running equals what’s in Git.”

# Inventory per site
kubectl get deploy,svc -n fleet-site-a
kubectl get deploy,svc -n fleet-site-b
kubectl get deploy,svc -n fleet-site-c


Each site runs a monitor service and N robot deployments (A=3, B=5, C=10 default). Robots are placeholders for vendor containers/adapters—swap images, keep the control plane.

# Quick robot counts (sanity vs. values files)
for ns in fleet-site-a fleet-site-b fleet-site-c; do
  echo -n "$ns robots: "
  kubectl get deploy -n $ns --no-headers | awk '$1 ~ /^robot-/{count++} END{print (count?count:0)}'
done

# Pods + IPs (one site deep-dive)
kubectl get pods -n fleet-site-a -o wide


Pods are Running; the monitor is a ClusterIP on port 8000. We will port-forward to reach the REST/metrics APIs.

Baseline Reset (run before scaling step)

This ensures Site A starts at 3 robots before the demo, avoiding “nothing to commit” errors and keeping the API totals in sync.

# Set count to 3 (Linux)
sed -i 's/^\([[:space:]]*count:[[:space:]]*\).*/ 3/' helm/values-site-a.yaml
# Set count to 3 (macOS/BSD sed)
sed -i '' 's/^\([[:space:]]*count:[[:space:]]*\).*/ 3/' helm/values-site-a.yaml

git add helm/values-site-a.yaml
git commit -m "Baseline: Site A at 3 robots" || true
git pull --rebase
git push

# Refresh & sync immediately
kubectl -n argocd annotate application fleet-site-a argocd.argoproj.io/refresh=hard --overwrite
kubectl -n argocd patch application fleet-site-a --type merge -p '{"operation":{"sync":{}}}'

# Ensure the monitor API reflects the new totals
kubectl -n fleet-site-a rollout restart deploy/fleet-monitor
kubectl -n fleet-site-a rollout status  deploy/fleet-monitor

# Watch it settle
kubectl get applications -n argocd -w

Founder demo — UI-first, business-centric flow
Pre-demo prep (2 minutes prior)
# One command to set port-forwards + print URLs
make founder-demo


Argo CD UI https://localhost:8080 (admin / password from the command). Set auto-refresh to 10s. Keep your terminal visible for the API proof points.

Preflight health & alignment (30s)
# Prove repo and cluster are on the same commit
git rev-parse HEAD
kubectl -n argocd get app fleet-site-a -o jsonpath='{.status.sync.revision}{"
"}'

# If SHAs differ, refresh the app cache
kubectl -n argocd annotate application fleet-site-a argocd.argoproj.io/refresh=hard --overwrite

# Confirm repo/branch and values file order (later files override earlier ones)
kubectl -n argocd get app fleet-site-a -o jsonpath='Repo:{.spec.source.repoURL} Rev:{.spec.source.targetRevision} Values:{.spec.source.helm.valueFiles}{"
"}'

# Sanity: Site A is currently at 3 robots
kubectl -n fleet-site-a get deploy | grep -c '^robot-'
curl -s http://localhost:8001/fleet | jq '.total_robots'

1) Single pane of glass (≈30s)

What to show: In Argo CD → Applications, three green cards fleet-site-a/b/c. Click fleet-site-a → Tree to reveal one monitor + three robot deployments.
Message: One repo templatizes every facility. The same workflow scales to hundreds of sites and multiple vendors without bespoke scripts or snowflake clusters.

Why buyers care: Lower time-to-deploy for new facilities; standardization reduces support load and training cost.

2) Scale a facility via Git (≈2–3 min)

GitHub UI path: edit helm/values-site-a.yaml, change count: 3 → count: 10, commit “Scale Site A to 10 robots for increased capacity”.

Terminal path:

# Set count to 10 (Linux)
sed -i 's/^\([[:space:]]*count:[[:space:]]*\).*/ 10/' helm/values-site-a.yaml
# Set count to 10 (macOS/BSD sed)
sed -i '' 's/^\([[:space:]]*count:[[:space:]]*\).*/ 10/' helm/values-site-a.yaml

git commit -am "Scale Site A to 10 robots" && git push


What unfolds in Argo CD: the fleet-site-a card transitions Synced → OutOfSync → Progressing → Synced; Tree view shows robot-3 … robot-9 appearing as reconciliation proceeds.

Business translation: Scaling is a reviewable commit, not a risky shell session. It leaves an audit trail, enables approvals, and is reversible. This is how to achieve 3× faster deployments with fewer mistakes.

If timing lags: force a refresh safely:

kubectl -n argocd annotate application fleet-site-a argocd.argoproj.io/refresh=hard --overwrite

Verify the scale (quick checks)
kubectl -n fleet-site-a get deploy | grep -c '^robot-'
kubectl -n fleet-site-a get pods | grep '^robot-' | wc -l
curl -s http://localhost:8001/fleet | jq '.total_robots'
# Expect: 10 across all checks


(If the API still reports 3 briefly, restart the monitor so totals re-scan the deployment set.)

kubectl -n fleet-site-a rollout restart deploy/fleet-monitor
kubectl -n fleet-site-a rollout status  deploy/fleet-monitor

3) Self-healing / drift correction (≈1 min)

Simulate human error to prove guardrails:

kubectl scale deploy robot-0 -n fleet-site-a --replicas=5
sleep 10
kubectl get deploy robot-0 -n fleet-site-a -o jsonpath='{.spec.replicas}'
# Expected: 1


What happens: the app briefly shows OutOfSync, then Argo CD repairs state back to Git (replicas=1).

Business translation: This kills snowflake drift and “mystery fixes.” It’s also a compliance story: production reflects Git; unauthorized changes are corrected and visible.

If it doesn’t auto-heal (rare):

kubectl -n argocd get application fleet-site-a -o yaml | grep -A3 syncPolicy
kubectl -n argocd patch application fleet-site-a --type merge -p '{"operation": {"sync": {}}}'

4) Real-time fleet telemetry (≈1 min)

Port-forwards are live from make founder-demo. Prove status and metrics:

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


Business translation: Vendor-agnostic APIs and metrics. Swap robot images/adapters without changing the control plane or dashboards. This aligns with “single pane of glass” claims.

5) Zero-downtime update (optional, ≈2–3 min)
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


What to watch: In fleet-site-a, the Rollout object gradually shifts traffic while health checks hold the line.

Prove zero downtime:

while true; do 
  curl -sf http://localhost:8001/health && echo " ✓ Service UP"
  sleep 1
done


Business translation: No interrupted active deployments. Updates are gated and safe to promote. This is critical for live floors and on-time SLAs.

6) Instant rollback (≈30s)

UI: fleet-site-a → History → select prior revision → Rollback.
Terminal:

git revert HEAD --no-edit && git push


Business translation: Recovery is a commit, not a firefight. Lower MTTR, higher confidence, safer change velocity.

Why this approach fits FleetGlue’s customers

Heterogeneous fleets, one control lane. Robot vendors become images/adapters. Helm + ApplicationSet fans out per-site configs.

Environment pipelines replace ad-hoc ops. PRs drive change; Argo CD reconciles; drift is detected and fixed.

Security & compliance built-in. Non-root containers, read-only rootfs, RBAC/AppProject guardrails; Git is the audit trail.

Scales from pilot to portfolio. One repo pattern works for 1 or 100+ sites, 3 or 3,000 robots. Multi-cluster is first-class.

Near-term add-ons for FleetGlue (roadmap signal):

Policy gates (e.g., OPA/Conftest) to block risky chart changes.

Metrics-driven rollouts (promote only if SLOs hold).

Per-vendor adapters standardizing telemetry/commands into a common API.

Secrets management (SOPS/External Secrets) for production readiness.

Environment pipelines (exec language)

Propose: bump robot count or image version.

Review: automated checks + human approval.

Merge → Reconcile: Argo CD applies to the target sites.

Validate: health, metrics, SLOs, dashboards.

Rollback: revert the commit if needed.

Benefits: fewer misconfigs, auditable history, safer handoffs, zero ad-hoc shell into prod.

Cloud-native challenges addressed (talk track)

Local vs remote clusters: demo uses Kind for speed; workflow is identical on EKS/GKE/AKS/on-prem.

Packaging & distribution: Helm standardizes installation + configuration; ApplicationSet scales it.

Visibility: inventory + Argo tree view provides “what exists” before you change anything.

Resilience: replicas, healing, and progressive delivery are first-class.

Walking skeleton: minimal end-to-end slice to test integrations and evolve safely.

Numbers to call out (tune to live results)

Site A robots: 3 → 10 after commit.

Rollout downtime: 0 failed health checks.

Self-healing: ~10s to revert unauthorized scale change.

API parity check: /fleet totals match Kubernetes deploy counts (proved live).

Executive Q&A (fast answers)

How is this better than SSH + scripts? Git is the desired state; Argo CD applies and maintains it. Changes are reviewed, auditable, reversible, and consistent across sites.

Multiple robot vendors and stacks? Yes—each is an image/adapter behind stable APIs/metrics. Control plane stays the same.

On-prem and cloud? Both—multi-cluster is first-class.

Security posture? Non-root containers, read-only rootfs, resource limits, RBAC guardrails; Git is the audit trail.

Time to first value? Hours for the platform; per-vendor integrations typically days (depends on SDKs/APIs).

Emergency fixes (keep handy)
# If Argo CD won’t sync
kubectl -n argocd patch application fleet-site-a --type merge -p '{"operation": {"sync": {"force": true}}}'

# If port-forwards died
make port-forward

# Reset to a clean demo baseline
make demo-reset

Post-demo cleanup
make demo-reset
# Resets Git state, kills port-forwards, restores defaults

Nice extras (use on request)
# Template → resource labels
kubectl get deploy -n fleet-site-a --show-labels

# Monitor service + endpoints
kubectl -n fleet-site-a get svc fleet-monitor
kubectl -n fleet-site-a get endpoints fleet-monitor

# ApplicationSet & AppProject wiring (fan-out & guardrails)
kubectl -n argocd get applicationset fleet-platform -o yaml | head -n 40
kubectl -n argocd get appprojects fleet-platform -o yaml | head -n 40

Close (one-liner)

Pilot with one vendor adapter using this Git-driven pipeline, then scale to more sites. Same control plane, faster deployments, lower risk, and business value you can prove on a dashboard.
