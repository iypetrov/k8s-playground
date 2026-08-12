.DEFAULT_GOAL := deploy-shoot

# Set SHELL to bash and configure options.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

KUBECONFIG_VIRTUAL ?= /root/go/src/github.com/gardener/gardener/dev-setup/kubeconfigs/virtual-garden/kubeconfig
KUBECONFIG_RUNTIME ?= /root/go/src/github.com/gardener/gardener/dev-setup/kubeconfigs/runtime/kubeconfig
KUBECONFIG_SHOOT ?= /root/go/src/github.com/gardener/gardener/dev-setup/kubeconfigs/shoot/kubeconfig


.PHONY: deploy-shoot
deploy-shoot:
	@kubectl --kubeconfig $(KUBECONFIG_VIRTUAL) apply -f shoot.yaml
