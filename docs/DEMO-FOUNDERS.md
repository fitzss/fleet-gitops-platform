# Fleet GitOps Platform - Founder Demo

**Audience:** FleetGlue founders (Docker-first, exploring Kubernetes/Helm/ArgoCD)  
**Duration:** 7-10 minutes  
**Focus:** Business outcomes, visual UI, minimal jargon

---

## What We'll Show (In Business Terms)

1. **One repository controls multiple facilities** - Template-based scaling
2. **Scale robots with a Git commit** - No manual cluster operations
3. **Self-healing infrastructure** - Automatic drift correction
4. **Real-time fleet telemetry** - Vendor-agnostic APIs
5. **Zero-downtime updates** (optional) - Deploy without disruption

---

## Pre-Demo Setup (2 minutes before call)

```bash
# One command to set everything up
make demo-setup

# This will:
# - Verify ArgoCD is running
# - Set up port forwards
# - Print access URLs
Open ArgoCD UI

Navigate to: https://localhost:8080
Login: admin / (password shown by make demo-setup)
Set Auto-Refresh to 10 seconds (top-right corner)
Arrange browser windows: ArgoCD on main screen, terminal on side


Demo Flow
1️⃣ Opening - Single Pane of Glass (30 seconds)
In ArgoCD UI:

Show the main Applications view
Point to three green cards: fleet-site-a, fleet-site-b, fleet-site-c

Say:

"This is your fleet control center. Each card represents a facility - Site A has 3 robots, Site B has 5, Site C has 10. All managed from one Git repository. This same interface scales to hundreds of facilities."

Click on fleet-site-a → Show Tree View
Say:

"Here's Site A's infrastructure - one monitoring service and three robot deployments, all defined by templates."


2️⃣ Scale a Facility via Git (2-3 minutes)
Option A: GitHub UI (Recommended for founders)

Open browser to: github.com/fitzss/fleet-gitops-platform
Navigate to: helm/values-site-a.yaml
Click Edit (pencil icon)
Change count: 3 to count: 10
Commit with message: "Scale Site A to 10 robots for increased capacity"

Option B: Terminal (if they prefer seeing Git)
bash# Simple one-liner
make demo-scale

# Or manually:
sed -i 's/count: 3/count: 10/' helm/values-site-a.yaml
git commit -am "Scale Site A to 10 robots" && git push
In ArgoCD UI:

Watch fleet-site-a status change:

Synced (green) → OutOfSync (yellow) → Progressing (blue) → Synced (green)


Click into fleet-site-a → Tree View
Watch robot-3 through robot-9 appear

Say:

"We just scaled from 3 to 10 robots with one Git commit. No SSH into servers, no kubectl commands, no manual deployments. Every change has an audit trail, can be reviewed, and can be instantly rolled back. This is how FleetGlue can promise '3x faster deployments.'"


3️⃣ Self-Healing Demo (1 minute)
Say:

"Now let me show you something powerful. What if someone tries to manually change the production cluster?"

In Terminal (one dramatic command):
bash# Try to manually break configuration
kubectl scale deploy robot-0 -n fleet-site-a --replicas=5
In ArgoCD UI:

Watch fleet-site-a briefly go OutOfSync (yellow)
Within 10 seconds, returns to Synced (green)

In Terminal (verify):
bash# Check it corrected itself
kubectl get deploy robot-0 -n fleet-site-a -o jsonpath='{.spec.replicas}'
# Output: 1
Say:

"The platform detected drift and automatically corrected it. Git is the single source of truth. This prevents configuration drift and 'snowflake' environments that cause production issues."


4️⃣ Real-Time Fleet Telemetry (1 minute)
In Terminal:
bash# Show health check
curl -s http://localhost:8001/health | jq

# Show fleet status for scaled Site A
curl -s http://localhost:8001/fleet | jq '{
  total_robots: .total_robots,
  operational: .operational,
  low_battery: .low_battery
}'

# Compare all three sites
echo "=== Robot Count Per Site ==="
echo "Site A: $(curl -s localhost:8001/fleet | jq -r .total_robots) robots"
echo "Site B: $(curl -s localhost:8002/fleet | jq -r .total_robots) robots"  
echo "Site C: $(curl -s localhost:8003/fleet | jq -r .total_robots) robots"

# Show Prometheus metrics (for monitoring)
curl -s http://localhost:8001/metrics | head -5
Say:

"Every robot reports telemetry. The fleet monitor aggregates it and exposes both JSON APIs and Prometheus metrics. This plugs directly into Grafana dashboards and alerting systems. It's vendor-agnostic - swap any robot vendor's container and keep the same control plane."


5️⃣ Zero-Downtime Update (Optional - 2 minutes)
Only if time permits and they're engaged
Say:

"Let me show you how we deploy updates without any service interruption."

In Terminal:
bash# Build and push v2
docker build -t fitzdoud/fleet-monitor:v2 services/monitor
docker push fitzdoud/fleet-monitor:v2

# Update via Git
cat > helm/values-gitops.yaml <<YAML
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
In ArgoCD UI:

Click fleet-site-a → find fleet-monitor
Watch the Rollout object show blue/green deployment

In Terminal (prove zero downtime):
bash# Service stays up during entire deployment
while true; do 
  curl -sf http://localhost:8001/health && echo " ✓ Service UP"
  sleep 1
done
Say:

"The old version serves traffic while the new version is validated. Zero downtime. This is critical for mission-critical robotics operations."


6️⃣ Instant Rollback (30 seconds)
In ArgoCD UI:

Click fleet-site-a → History tab
Show previous versions with Git commits
Click Rollback on previous version

Or in Terminal:
bashgit revert HEAD --no-edit && git push
Say:

"Any change can be instantly rolled back. Full audit trail, complete reversibility. This is the safety net operations teams need."


Closing - Connect to FleetGlue Value Props
Say:

"What we just demonstrated maps directly to FleetGlue's promises:

'Deploy at the speed of light' - Git push to production in seconds
'Single pane of glass' - ArgoCD shows all facilities
'No interrupted deployments' - Blue/green ensures zero downtime
'Reduce errors by 90%' - GitOps eliminates manual mistakes
'Vendor agnostic' - Swap any robot vendor, keep the same platform

This same architecture scales from 3 robots to 3,000, from 1 facility to 100. It's the operational backbone FleetGlue needs."


Q&A Talking Points
"How does this compare to traditional deployments?"

"Traditional: SSH into each server, run scripts, hope nothing breaks.
GitOps: Change Git, everything updates automatically with rollback safety."

"What about different robot vendors?"

"The beauty is vendor independence. Swap the container image - whether it's ROS, proprietary SDK, or custom protocol - the GitOps control plane remains the same."

"How fast can we implement this?"

"The platform you're seeing can be deployed in hours. Integrating real robot containers depends on their existing architecture, but typically days, not months."

"What about security?"

"Everything runs as non-root, containers are signed, and Git provides complete audit trails. This exceeds most compliance requirements."


Emergency Fixes
If something goes wrong, stay calm and use these:
bash# If ArgoCD won't sync
kubectl -n argocd patch application fleet-site-a \
  --type merge -p '{"operation": {"sync": {"force": true}}}'

# If port-forwards died
make port-forward

# Reset everything
make demo-reset

Post-Demo
bash# Clean up
make demo-reset

# This will:
# - Reset Git to original state
# - Kill port-forwards
# - Scale sites back to defaults

