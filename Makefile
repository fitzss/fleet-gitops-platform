# Fleet GitOps Platform - Operations
REG=fitzdoud
VERSION=v1

.PHONY: build push login deploy clean demo verify

login:
	@echo "Logging into Docker Hub..."
	docker login

build:
	docker build -t $(REG)/fleet-robot:$(VERSION) services/robot
	docker build -t $(REG)/fleet-monitor:$(VERSION) services/monitor

push: login
	docker push $(REG)/fleet-robot:$(VERSION)
	docker push $(REG)/fleet-monitor:$(VERSION)

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
	@sleep 2
	@printf "Port forwards ready:\n"
	@printf "  Site A: http://localhost:8001/fleet\n"
	@printf "  Site B: http://localhost:8002/fleet\n"
	@printf "  Site C: http://localhost:8003/fleet\n"

test-fleet:
	@curl -sf http://localhost:8001/fleet | jq '.total_robots' || echo "Site A not accessible"
	@curl -sf http://localhost:8002/fleet | jq '.total_robots' || echo "Site B not accessible"
	@curl -sf http://localhost:8003/fleet | jq '.total_robots' || echo "Site C not accessible"

demo: bootstrap-argocd
	@printf "Fleet platform ready for demo!\n"
	@printf "Run: make verify\n"
	@printf "Then: make port-forward\n"

clean:
	kubectl delete applicationset fleet-platform -n argocd 2>/dev/null || true
	kubectl delete ns fleet-site-a fleet-site-b fleet-site-c 2>/dev/null || true
	@printf "Cleanup complete\n"
