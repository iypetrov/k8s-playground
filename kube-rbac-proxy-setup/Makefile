.DEFAULT_GOAL := k8s-up

# Set SHELL to bash and configure options.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

CERT_DIR ?= certs

.PHONY: kind-up
kind-up:
	@kind create cluster --name kube-rbac-proxy-setup --config kind.yaml

.PHONY: kind-down
kind-down:
	@kind delete cluster --name kube-rbac-proxy-setup

.PHONY: generate-certificates
generate-certificates:
	@chmod +x scripts/generate-certificates.sh && bash scripts/generate-certificates.sh

.PHONY: deploy
deploy:
	@helm repo add stakater https://stakater.github.io/stakater-charts
	@helm repo update
	@helm upgrade --install reloader stakater/reloader \
		--namespace reloader \
		--create-namespace
	@helm upgrade \
		--install \
		cert-manager oci://quay.io/jetstack/charts/cert-manager \
		--version v1.21.2 \
		--namespace cert-manager \
		--create-namespace \
		--set crds.enabled=true \
		--wait
	@kubectl create -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/refs/heads/main/bundle.yaml || true
	@kubectl rollout status deployment/prometheus-operator -n default --timeout=120s
	@helm repo add perses https://perses.github.io/helm-charts
	@helm repo update
	@helm upgrade --install perses-operator perses/perses-operator --wait --create-namespace
	@kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
	@kubectl rollout status deployment/opentelemetry-operator-controller-manager -n opentelemetry-operator-system --timeout=120s
	@kubectl apply -f k8s/00-prometheus.yaml
	@kubectl apply -f k8s/01-perses.yaml
	@echo "Setup the experimental pipeline with kube-rbac-proxy..."
	@kubectl apply -f k8s/02-namespace.yaml
	@kubectl --namespace experiment \
		create secret generic otel-receiver-tls \
		--from-file=tls.crt=$(CERT_DIR)/server.crt \
		--from-file=tls.key=$(CERT_DIR)/server.key \
		--from-file=ca.crt=$(CERT_DIR)/ca.crt \
		--dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -f k8s/03-otel-receiver-with-kube-rbac-proxy.yaml
	@kubectl apply -f k8s/04-otel-exporter.yaml

.PHONY: delve-setup
delve-setup:
	@POD=$$(kubectl -n experiment get pod -l app=otel-receiver -o jsonpath='{.items[0].metadata.name}'); \
	kubectl -n experiment debug "$$POD" \
		--image=golang:1.24 \
		--target=kube-rbac-proxy \
		--share-processes \
		-- /bin/sh -c \
		'go install github.com/go-delve/delve/cmd/dlv@latest; until _PID=$$(pgrep kube-rbac-proxy); do sleep 1; done; exec dlv attach "$$_PID" --headless --listen=:2345 --api-version=2 --accept-multiclient --continue' & \
	echo "Waiting for dlv to be ready..."; \
	until kubectl -n experiment port-forward "$$POD" 2345:2345 2>/dev/null; do sleep 2; done

.PHONY: delve
delve:
	@dlv connect localhost:2345

.PHONY: kube-apiserver-metrics
kube-apiserver-metrics:
	@kubectl get --raw /metrics
