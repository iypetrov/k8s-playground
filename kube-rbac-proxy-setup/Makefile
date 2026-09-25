.DEFAULT_GOAL := k8s-up

# Set SHELL to bash and configure options.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

.PHONY: kind-up
kind-up:
	@kind create cluster --name kube-rbac-proxy-setup --config kind.yaml

.PHONY: kind-down
kind-down:
	@kind delete cluster --name kube-rbac-proxy-setup

.PHONY: k8s-up
k8s-up:
	@helm repo add stakater https://stakater.github.io/stakater-charts
	@helm repo update
	@helm upgrade --install reloader stakater/reloader \
	  --namespace reloader \
	  --create-namespace
	@kubectl apply -f k8s/00-namespace.yaml
	@kubectl apply -f k8s/01-otel-receiver-with-kube-rbac-proxy.yaml
	@kubectl apply -f k8s/02-otel-exporter.yaml
