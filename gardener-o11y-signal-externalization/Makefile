.DEFAULT_GOAL := o11y-receiver

# Set SHELL to bash and configure options.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

KUBECONFIG_VIRTUAL ?= /root/go/src/github.com/gardener/gardener/dev-setup/kubeconfigs/virtual-garden/kubeconfig
KUBECONFIG_RUNTIME ?= /root/go/src/github.com/gardener/gardener/dev-setup/kubeconfigs/runtime/kubeconfig
KUBECONFIG_SHOOT ?= /root/go/src/github.com/gardener/gardener/dev-setup/kubeconfigs/shoot/kubeconfig

.PHONY: deploy-shoot
deploy-shoot:
	@kubectl --kubeconfig $(KUBECONFIG_VIRTUAL) apply -f shoot.yaml
	@kubectl --kubeconfig $(KUBECONFIG_RUNTIME) --namespace shoot--local--local annotate extensions otelcol gardener.cloud/operation=reconcile

.PHONY: sync-hyperdx-api-key
sync-hyperdx-api-key:
	@echo "Injecting bearer-token auth references into shoot.yaml..."
	@yq -i '.spec.extensions[0].providerConfig.spec.targets[0].exporter.otlp_http.token.resourceRef = {"name": "clickstack-bearer-token", "dataKey": "token"}' shoot.yaml
	@yq -i '.spec.resources = [{"name": "clickstack-bearer-token", "resourceRef": {"apiVersion": "v1", "kind": "Secret", "name": "hyperdx-otelcol-bearer-token"}}]' shoot.yaml
	@echo --- >> shoot.yaml
	@echo "Reading ingestion token from the ClickStack collector..."
	@TOKEN=$$(kubectl --kubeconfig $(KUBECONFIG_SHOOT) --namespace clickstack exec deploy/clickstack-otel-collector -- grep -A1 'tokens:' /etc/otel/supervisor-data/effective.yaml | tail -n1 | awk '{print $$NF}' | tr -d '[:space:]'); \
	  if [ -z "$$TOKEN" ]; then echo "ERROR: could not read token from ClickStack collector" >&2; exit 1; fi; \
	  echo "Token: $$TOKEN"; \
	  kubectl --kubeconfig $(KUBECONFIG_VIRTUAL) --namespace garden-local create secret generic hyperdx-otelcol-bearer-token \
	    --from-literal=token="$$TOKEN" --dry-run=client -o yaml | kubectl --kubeconfig $(KUBECONFIG_VIRTUAL) apply -f -


.PHONY: deploy-stakater-reloader
deploy-stakater-reloader:
	@KUBECONFIG=$(KUBECONFIG_SHOOT) helm repo add stakater https://stakater.github.io/stakater-charts
	@KUBECONFIG=$(KUBECONFIG_SHOOT) helm repo update
	@KUBECONFIG=$(KUBECONFIG_SHOOT) helm upgrade --install reloader stakater/reloader \
	  --namespace reloader \
	  --create-namespace \
	  --values values/reloader.yaml

.PHONY: deploy-clickstack
deploy-clickstack:
	@KUBECONFIG=$(KUBECONFIG_SHOOT) helm repo add clickstack https://clickhouse.github.io/ClickStack-helm-charts
	@KUBECONFIG=$(KUBECONFIG_SHOOT) helm repo update
	@KUBECONFIG=$(KUBECONFIG_SHOOT) helm upgrade --install clickstack-operators clickstack/clickstack-operators \
	  --namespace clickstack \
	  --create-namespace \
	  --wait \
	  --values values/clickstack-operators.yaml
	@KUBECONFIG=$(KUBECONFIG_SHOOT) helm upgrade --install clickstack clickstack/clickstack \
	  --namespace clickstack \
	  --create-namespace \
	  --values values/clickstack.yaml


.PHONY: o11y-receiver
o11y-receiver: deploy-stakater-reloader deploy-clickstack
	@: $${CLOUDFLARED_TUNNEL_TOKEN:?CLOUDFLARED_TUNNEL_TOKEN is not set — export it before running this target}
	@trap 'rm -f k8s/cloudflared-creds.env' EXIT; \
	  printf 'TUNNEL_TOKEN=%s\n' "$$CLOUDFLARED_TUNNEL_TOKEN" > k8s/cloudflared-creds.env; \
	  kubectl --kubeconfig $(KUBECONFIG_SHOOT) apply -k k8s/
