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

.PHONY: k8s-up
k8s-up:
	@helm repo add stakater https://stakater.github.io/stakater-charts
	@helm repo update
	@helm upgrade --install reloader stakater/reloader \
		--namespace reloader \
		--create-namespace
	@kubectl apply -f k8s/00-namespace.yaml
	@kubectl --namespace experiment \
		create secret generic otel-receiver-tls \
		--from-file=tls.crt=$(CERT_DIR)/server.crt \
		--from-file=tls.key=$(CERT_DIR)/server.key \
		--from-file=ca.crt=$(CERT_DIR)/ca.crt \
		--dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -f k8s/01-otel-receiver-with-kube-rbac-proxy.yaml
	@kubectl apply -f k8s/02-otel-exporter.yaml

.PHONY: delve-kube-rbac-proxy
delve-kube-rbac-proxy:
	@sudo dlv attach "$(pgrep -f '/usr/local/bin/kube-rbac-proxy')"
