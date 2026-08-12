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

# Set the following envs before running this goal:
# - NGROK_AUTHTOKEN
# - NGROK_API_KEY
#
# See the link below for more details:
# https://ngrok.com/docs/getting-started/kubernetes/ingress#simple.
.PHONY: deploy-ngrok-operator
deploy-ngrok-operator:
	@: $${NGROK_API_KEY:?NGROK_API_KEY is not set — export it before running this target}
	@: $${NGROK_AUTHTOKEN:?NGROK_AUTHTOKEN is not set — export it before running this target}
	@KUBECONFIG=$(KUBECONFIG_SHOOT) helm repo add ngrok https://charts.ngrok.com
	@KUBECONFIG=$(KUBECONFIG_SHOOT) helm repo update
	@KUBECONFIG=$(KUBECONFIG_SHOOT) helm upgrade --install ngrok-operator ngrok/ngrok-operator \
	  --namespace ngrok-operator \
	  --create-namespace \
	  --values values/ngrok-operator.yaml \
	  --set credentials.apiKey="$$NGROK_API_KEY" \
	  --set credentials.authtoken="$$NGROK_AUTHTOKEN"

.PHONY: deploy-clickstack
deploy-clickstack:
	@KUBECONFIG=$(KUBECONFIG_SHOOT) helm repo add clickstack https://clickhouse.github.io/ClickStack-helm-charts
	@KUBECONFIG=$(KUBECONFIG_SHOOT) helm repo update
	@KUBECONFIG=$(KUBECONFIG_SHOOT) helm upgrade --install clickstack-operators clickstack/clickstack-operators \
	  --create-namespace \
	  --values values/clickstack-operators.yaml && \
	 KUBECONFIG=$(KUBECONFIG_SHOOT) helm upgrade --install clickstack clickstack/clickstack \
	  --create-namespace \
	  --values values/clickstack.yaml \


.PHONY: o11y-receiver
o11y-receiver: deploy-ngrok-operator deploy-clickstack
	@kubectl --kubeconfig $(KUBECONFIG_SHOOT) apply -k k8s/
