CLUSTER?=otel-operator
OTEL_GO_INSTRUMENTATION_IMAGE?=ghcr.io/open-telemetry/opentelemetry-go-instrumentation/autoinstrumentation-go:v0.24.0

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: kind-load
kind-load: ## Build and load both images into the kind cluster.
	@$(MAKE) -C http-server docker-build
	@$(MAKE) -C batch-job docker-build
	@docker save http-server:latest | docker exec -i $(CLUSTER)-control-plane ctr -n k8s.io images import -
	@docker save batch-job:latest   | docker exec -i $(CLUSTER)-control-plane ctr -n k8s.io images import -
	@docker pull $(OTEL_GO_INSTRUMENTATION_IMAGE)
	@docker save $(OTEL_GO_INSTRUMENTATION_IMAGE) | docker exec -i $(CLUSTER)-control-plane ctr -n k8s.io images import -

.PHONY: apply
apply: ## Apply all manifests.
	@kubectl apply -f 01_receiver.yaml
	@kubectl apply -f 02_http-server.yaml
