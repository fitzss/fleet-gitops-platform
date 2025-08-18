Fleet Platform Demo Script
Pre-Demo Setup (5 minutes)
bash# 1. Create cluster
kind delete cluster --name fleet-demo || true
kind create cluster --name fleet-demo --image kindest/node:v1.30.2

# 2. Build and push
make build push

# 3. Deploy platform
make bootstrap-argocd

# 4. Wait for sync
sleep 30
make verify

# 5. Set up access
make port-forward
make test-fleet
Demo Flow (5 minutes)
1. Multi-Site Overview (30 sec)
bashmake verify
Say: "Three facilities managed from one Git repository"
2. Scale via Git (1 min)
bashvi helm/values-site-a.yaml  # Change count: 3 to 10
git commit -am "Scale Site A to 10 robots"
git push
kubectl get pods -n fleet-site-a -w
Say: "Declarative scaling through Git - full audit trail"
3. Self-Healing (30 sec)
bashkubectl scale deploy robot-0 -n fleet-site-a --replicas=5
sleep 10
kubectl get deploy robot-0 -n fleet-site-a
Say: "Drift auto-corrected - Git is the source of truth"
4. Fleet API (30 sec)
bashcurl -s localhost:8001/fleet | jq '.total_robots, .operational'
Say: "Real-time telemetry aggregation across all robots"
5. (Optional) Zero-Downtime Update (2 min)
bash# Build v2
docker build -t fitzdoud/fleet-monitor:v2 services/monitor
docker push fitzdoud/fleet-monitor:v2

# Enable rollouts and update
sed -i 's/enabled: false/enabled: true/' helm/values-gitops.yaml
sed -i 's|fleet-monitor:v1|fleet-monitor:v2|' helm/values-gitops.yaml
git commit -am "Blue/green deployment to v2"
git push

# Watch rollout
kubectl get rollout -n fleet-site-a fleet-monitor -w
Say: "Zero-downtime updates with blue/green deployments"
Key Messages

Git is truth - All changes through version control
Multi-site scale - Same pattern for 3 or 300 sites
Self-healing - Automatic drift correction
Production ready - Security, monitoring, rollouts
