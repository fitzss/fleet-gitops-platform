# Fleet GitOps Platform - Operations
REG=fitzdoud
VERSION=v1

.PHONY: build push login deploy clean demo verify port-forward test-fleet
.PHONY: demo-setup demo-scale demo-drift demo-reset
.PHONY: founder-demo founder-scale founder-status

# Docker Operations
login:
	@echo "Logging into Docker Hub..."
	docker login

build:
	docker build -t $(REG)/fleet-robot:$(VERSION) services/robot
	docker build -t $(REG)/fleet-monitor:$(VERSION) services/monitor

push: login
	docker push $(REG)/fleet-robot:$(VERSION)
	docker push $(REG)/fleet-monitor:$(VERSION)

# ArgoCD and Platform Setup
bootstrap-argocd:
	kubectl create ns argocd || true
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	kubectl wait --for=condition=available deploy/argocd-server -n argocd --timeout=300s
	kubectl wait --for=condition=available deploy/argocd-applicationset-controller -n argocd --timeout=60s || \
		kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/applicationset/install.yaml
	kubectl apply -f argocd/app-project.yaml
	kubectl apply -f argocd/applicationset.yaml

rollouts:
	kubectl create ns argo-rollouts || true
	kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Verification and Monitoring
verify:
	@printf "=== Fleet Status ===\n"
	@kubectl get applications -n argocd 2>/dev/null || echo "ArgoCD not installed"
	@printf "\n=== Robot Count ===\n"
	@for ns in fleet-site-a fleet-site-b fleet-site-c; do \
		count=$$(kubectl get pods -n $$ns 2>/dev/null | grep -c robot- || echo 0); \
		printf "$$ns: $$count robots\n"; \
	done
	@printf "\n=== Service Health ===\n"
	@for ns in fleet-site-a fleet-site-b fleet-site-c; do \
		kubectl get svc fleet-monitor -n $$ns 2>/dev/null >/dev/null && \
			printf "$$ns: ✓ Monitor service ready\n" || \
			printf "$$ns: ✗ Not deployed\n"; \
	done

port-forward:
	@echo "Setting up port forwards..."
	@kubectl port-forward -n fleet-site-a svc/fleet-monitor 8001:8000 >/dev/null 2>&1 &
	@kubectl port-forward -n fleet-site-b svc/fleet-monitor 8002:8000 >/dev/null 2>&1 &
	@kubectl port-forward -n fleet-site-c svc/fleet-monitor 8003:8000 >/dev/null 2>&1 &
	@kubectl port-forward -n argocd svc/argocd-server 8080:443 >/dev/null 2>&1 &
	@sleep 3
	@printf "Port forwards ready:\n"
	@printf "  ArgoCD UI: https://localhost:8080\n"
	@printf "  Site A: http://localhost:8001/fleet\n"
	@printf "  Site B: http://localhost:8002/fleet\n"
	@printf "  Site C: http://localhost:8003/fleet\n"

test-fleet:
	@curl -sf http://localhost:8001/fleet | jq '.total_robots' || echo "Site A not accessible"
	@curl -sf http://localhost:8002/fleet | jq '.total_robots' || echo "Site B not accessible"
	@curl -sf http://localhost:8003/fleet | jq '.total_robots' || echo "Site C not accessible"

# General Demo Helpers
demo: bootstrap-argocd
	@printf "Fleet platform ready for demo!\n"
	@printf "Run: make verify\n"
	@printf "Then: make port-forward\n"

demo-setup:
	@printf "=== Demo Setup ===\n"
	@kubectl get applications -n argocd >/dev/null 2>&1 || (echo "ERROR: ArgoCD not ready" && exit 1)
	@make port-forward
	@sleep 2
	@printf "\n✓ Demo ready!\n"
	@printf "ArgoCD UI: https://localhost:8080\n"
	@printf "Fleet APIs: localhost:8001, 8002, 8003\n"

demo-scale:
	@printf "Scaling Site A to 10 robots...\n"
	@sed -i 's/count: 3/count: 10/' helm/values-site-a.yaml 2>/dev/null || \
		sed -i '' 's/count: 3/count: 10/' helm/values-site-a.yaml
	@git add helm/values-site-a.yaml
	@git commit -m "Demo: Scale Site A to 10 robots"
	@git push
	@printf "✓ Pushed! Watch ArgoCD sync...\n"

demo-drift:
	@printf "Inducing drift on robot-0...\n"
	@kubectl scale deploy robot-0 -n fleet-site-a --replicas=5
	@sleep 10
	@printf "Replicas now: "
	@kubectl get deploy robot-0 -n fleet-site-a -o jsonpath='{.spec.replicas}'
	@printf "\n✓ Should be back to 1 (self-healed)\n"

demo-reset:
	@printf "Resetting demo state...\n"
	@git checkout helm/values-site-a.yaml helm/values-gitops.yaml 2>/dev/null || true
	@git commit -am "Reset demo state" 2>/dev/null || true
	@git push 2>/dev/null || true
	@pkill -f port-forward || true
	@printf "✓ Demo reset complete\n"

# Founder-Specific Demo Helpers
founder-demo: demo-setup
	@printf "\n=== Ready for Founder Demo ===\n"
	@printf "ArgoCD UI: https://localhost:8080\n"
	@printf "Username: admin\n"
	@printf "Password: "
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
	@printf "\n\nFleet APIs:\n"
	@printf "  Site A: http://localhost:8001/fleet\n"
	@printf "  Site B: http://localhost:8002/fleet\n"
	@printf "  Site C: http://localhost:8003/fleet\n"
	@printf "\nGitHub Repo: https://github.com/fitzss/fleet-gitops-platform\n"
	@printf "\n💡 Tip: Set Auto-Refresh to 10s in ArgoCD UI (top-right)\n"
	@printf "\n📋 Quick Commands:\n"
	@printf "  make founder-scale  - Scale Site A to 10 robots\n"
	@printf "  make founder-status - Show fleet status\n"
	@printf "  make demo-drift     - Demo self-healing\n"
	@printf "  make demo-reset     - Reset everything\n"

founder-scale:
	@printf "Scaling Site A to 10 robots...\n"
	@sed -i 's/count: 3/count: 10/' helm/values-site-a.yaml 2>/dev/null || \
		sed -i '' 's/count: 3/count: 10/' helm/values-site-a.yaml
	@git add helm/values-site-a.yaml
	@git commit -m "Scale Site A to 10 robots for increased capacity"
	@git push
	@printf "✓ Pushed to Git!\n"
	@printf "🔄 Watch ArgoCD UI: fleet-site-a will go OutOfSync → Synced\n"
	@printf "📊 Verify with: make founder-status\n"

founder-status:
	@printf "=== Fleet Status ===\n"
	@for port in 8001 8002 8003; do \
		site=$$([ $$port = 8001 ] && echo "A" || ([ $$port = 8002 ] && echo "B" || echo "C")); \
		robots=$$(curl -s localhost:$$port/fleet 2>/dev/null | jq -r .total_robots || echo "?"); \
		operational=$$(curl -s localhost:$$port/fleet 2>/dev/null | jq -r .operational || echo "?"); \
		printf "Site $$site: $$robots robots ($$operational operational)\n"; \
	done
	@printf "\n=== ArgoCD App Status ===\n"
	@kubectl get applications -n argocd --no-headers 2>/dev/null | awk '{printf "%-20s %s\n", $$1":", $$2}' || echo "ArgoCD not ready"
	@printf "\n=== Quick Health Check ===\n"
	@for port in 8001 8002 8003; do \
		curl -sf http://localhost:$$port/health >/dev/null 2>&1 && \
			printf "Port $$port: ✓ Healthy\n" || \
			printf "Port $$port: ✗ Not responding\n"; \
	done

# Cleanup
clean:
	kubectl delete applicationset fleet-platform -n argocd 2>/dev/null || true
	kubectl delete ns fleet-site-a fleet-site-b fleet-site-c 2>/dev/null || true
	@pkill -f port-forward || true
	@printf "Cleanup complete\n"

# Help
help:
	@printf "Fleet GitOps Platform - Available Commands\n"
	@printf "==========================================\n\n"
	@printf "Setup:\n"
	@printf "  make build              - Build Docker images\n"
	@printf "  make push               - Push images to Docker Hub\n"
	@printf "  make bootstrap-argocd   - Install ArgoCD and applications\n"
	@printf "  make rollouts           - Install Argo Rollouts\n\n"
	@printf "Demo Commands:\n"
	@printf "  make founder-demo       - Start founder demo (recommended)\n"
	@printf "  make founder-scale      - Scale Site A to 10 robots\n"
	@printf "  make founder-status     - Show detailed fleet status\n"
	@printf "  make demo-drift         - Demo self-healing\n"
	@printf "  make demo-reset         - Reset to original state\n\n"
	@printf "Utilities:\n"
	@printf "  make verify             - Check platform status\n"
	@printf "  make port-forward       - Set up port forwards\n"
	@printf "  make test-fleet         - Test fleet APIs\n"
	@printf "  make clean              - Remove everything\n"
	@printf "  make help               - Show this help\n"

# Default target
all: help

