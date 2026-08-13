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
o11y-receiver: deploy-ngrok-operator deploy-clickstack
	@: $${CLOUDFLARED_TUNNEL_TOKEN:?CLOUDFLARED_TUNNEL_TOKEN is not set — export it before running this target}
	@kubectl --kubeconfig $(KUBECONFIG_SHOOT) create secret generic cloudflared-creds --from-literal=TUNNEL_TOKEN="$$CLOUDFLARED_TUNNEL_TOKEN"
	@kubectl --kubeconfig $(KUBECONFIG_SHOOT) apply -k k8s/
