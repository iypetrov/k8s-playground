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
	@kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=opentelemetry-operator -n opentelemetry-operator-system --timeout=60s
	@kubectl apply -f k8s/00-prometheus.yaml
	@kubectl apply -f k8s/01-perses.yaml
	@helm repo add fluent https://fluent.github.io/helm-charts
	@helm repo update
	@helm upgrade --install fluent-operator fluent/fluent-operator --create-namespace -n fluent --wait
	@echo "Setup the experimental pipeline with kube-rbac-proxy..."
	@kubectl apply -f k8s/02-namespace.yaml
	@kubectl --namespace experiment \
		create secret generic otel-receiver-tls \
		--from-file=tls.crt=$(CERT_DIR)/server.crt \
		--from-file=tls.key=$(CERT_DIR)/server.key \
		--from-file=ca.crt=$(CERT_DIR)/ca.crt \
		--dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -f k8s/03-otel-receiver-with-kube-rbac-proxy.yaml
	@# fluent-operator mounts secrets from the FluentBit CR's namespace (fluent), so the CA must exist there too
	@kubectl --namespace fluent \
		create secret generic otel-receiver-tls \
		--from-file=tls.crt=$(CERT_DIR)/server.crt \
		--from-file=tls.key=$(CERT_DIR)/server.key \
		--from-file=ca.crt=$(CERT_DIR)/ca.crt \
		--dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -f k8s/04-fluent-bit-exporter.yaml

.PHONY: port-forward-up
port-forward-up:
	@kubectl port-forward -n perses svc/perses 8080:8080 &
	@kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
	@kubectl port-forward -n experiment svc/otel-receiver-collector 6969:6969 &
	@kubectl port-forward -n experiment svc/otel-receiver-collector 2345:2345 &

.PHONY: port-forward-down
port-forward-down:
	@lsof -ti :8080 | xargs kill -9
	@lsof -ti :9090 | xargs kill -9
	@lsof -ti :6960 | xargs kill -9
	@lsof -ti :2340 | xargs kill -9

.PHONY: delve
delve:
	@dlv connect localhost:2345

.PHONY: metrics
metrics:
	@curl localhost:6969/metrics

.PHONY: pprof
pprof:
	@go tool pprof -http=:3000 http://localhost:6969/debug/pprof/profile?seconds=30

.PHONY: controlplane-start
controlplane-start:
	@docker start kind-control-plane

.PHONY: controlplane-stop
controlplane-start:
	@docker stop kind-control-plane

.PHONY: kube-apiserver-metrics
kube-apiserver-metrics:
	@kubectl get --raw /metrics
