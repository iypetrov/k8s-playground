.DEFAULT_GOAL := k8s-up

# Set SHELL to bash and configure options.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

.PHONY: deploy-stakater-reloader
deploy-stakater-reloader:

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
	@kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.1/cert-manager.yaml
	@kubectl wait --for=condition=Available deployment --all -n cert-manager --timeout=120s
	@kubectl wait --for=condition=Ready pod --all -n cert-manager --timeout=120s
	@until kubectl get secret -n cert-manager cert-manager-webhook-ca 2>/dev/null | grep -q cert-manager-webhook-ca; do sleep 2; done
	@kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
	@kubectl wait --for=condition=Available deployment/opentelemetry-operator-controller-manager -n opentelemetry-operator-system --timeout=120s
	@kubectl patch deployment opentelemetry-operator-controller-manager -n opentelemetry-operator-system \
	  --type=json -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--enable-go-instrumentation=true"}]'
	@kubectl rollout status deployment/opentelemetry-operator-controller-manager -n opentelemetry-operator-system --timeout=120s
	@kubectl apply -f k8s/01-jaeger.yaml
	@kubectl apply -f k8s/02-namespace.yaml
	@kubectl apply -f k8s/03-auto-instrumentation.yaml
	@kubectl apply -f k8s/04-otel-col-receiver-with-kube-rbac-proxy.yaml
	@kubectl apply -f k8s/05-otel-col-exporter.yaml
