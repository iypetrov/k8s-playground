.DEFAULT_GOAL := o11y-receiver

# Set SHELL to bash and configure options.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

KUBECONFIG_VIRTUAL ?= /root/go/src/github.com/gardener/gardener/dev-setup/kubeconfigs/virtual-garden/kubeconfig
KUBECONFIG_RUNTIME ?= /root/go/src/github.com/gardener/gardener/dev-setup/kubeconfigs/runtime/kubeconfig
KUBECONFIG_SHOOT ?= /root/go/src/github.com/gardener/gardener/dev-setup/kubeconfigs/shoot/kubeconfig

# Fixed bearer token the ClickStack OTLP receiver enforces.
# - Must match hyperdx.secrets.OTLP_FIXED_TOKEN in values/clickstack.yaml.
OTLP_FIXED_TOKEN ?= 00000000-0000-4000-8000-000000000000
CERT_DIR ?= certs

# Use it only for the bootstraping.
.PHONY: deploy-base-shoot
deploy-base-shoot:
	@kubectl --kubeconfig $(KUBECONFIG_VIRTUAL) apply -f shoot.base.yaml

.PHONY: deploy-shoot
deploy-shoot:
	@kubectl --kubeconfig $(KUBECONFIG_VIRTUAL) apply -f shoot.yaml
	@kubectl --kubeconfig $(KUBECONFIG_RUNTIME) --namespace shoot--local--local annotate extensions otelcol gardener.cloud/operation=reconcile

.PHONY: generate-certificates
generate-certificates:
	@chmod +x scripts/generate-certificates.sh && bash scripts/generate-certificates.sh
	@echo "ClickStack..."
	@kubectl --kubeconfig $(KUBECONFIG_SHOOT) create namespace clickstack
	@kubectl --kubeconfig $(KUBECONFIG_SHOOT) --namespace clickstack \
		create secret generic clickstack-otel-tls \
	 	--from-file=tls.crt=$(CERT_DIR)/clickstack-server.crt \
	  	--from-file=tls.key=$(CERT_DIR)/clickstack-server.key \
	  	--from-file=ca.crt=$(CERT_DIR)/ca.crt \
		--dry-run=client -o yaml | kubectl --kubeconfig $(KUBECONFIG_SHOOT) apply -f -
	@kubectl --kubeconfig $(KUBECONFIG_VIRTUAL) --namespace garden-local \
		create secret generic hyperdx-otelcol-bearer-token \
	  	--from-literal=token="$(OTLP_FIXED_TOKEN)" \
		--dry-run=client -o yaml | kubectl --kubeconfig $(KUBECONFIG_VIRTUAL) apply -f -
	@kubectl --kubeconfig $(KUBECONFIG_VIRTUAL) --namespace garden-local \
		create secret generic hyperdx-otelcol-tls \
	 	--from-file=ca.crt=$(CERT_DIR)/ca.crt \
		--from-file=client.crt=$(CERT_DIR)/clickstack-client.crt \
	  	--from-file=client.key=$(CERT_DIR)/clickstack-client.key \
		--dry-run=client -o yaml | kubectl --kubeconfig $(KUBECONFIG_VIRTUAL) apply -f -


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
