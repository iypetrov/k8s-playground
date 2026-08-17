```bash
# Setup for each tmux panel
export KUBECONFIG_VIRTUAL=/root/go/src/github.com/gardener/gardener/dev-setup/kubeconfigs/virtual-garden/kubeconfig
export KUBECONFIG_RUNTIME=/root/go/src/github.com/gardener/gardener/dev-setup/kubeconfigs/runtime/kubeconfig
export KUBECONFIG=$KUBECONFIG_RUNTIME
export KUBECONFIG_SHOOT=/root/go/src/github.com/gardener/gardener/dev-setup/kubeconfigs/shoot/kubeconfig
alias kr="kubectl --kubeconfig $KUBECONFIG_RUNTIME"
alias kv="kubectl --kubeconfig $KUBECONFIG_VIRTUAL"
alias ks="kubectl --kubeconfig $KUBECONFIG_SHOOT"

# run gardener locally (gardener)
make -C /root/go/src/github.com/gardener/gardener kind-up gardener-up

# deploy the otelcol extesnion (gardener-extension-otelcol)
make -C /root/go/src/github.com/gardener/gardener-extension-otel-col deploy-operator

# create the shoot cluster (this)
make deploy-shoot 
KUBECONFIG=$KUBECONFIG_VIRTUAL bash /root/go/src/github.com/gardener/gardener/hack/usage/generate-kubeconfig.sh shoot > $KUBECONFIG_SHOOT

# deploy shoot's testing o11y stacks
make -C /root/go/src/github.com/gardener/k8s-playground/gardener-o11y-signal-externalization o11y-receiver

# generate certificates + deploy the shoot
make -C /root/go/src/github.com/gardener/k8s-playground/gardener-o11y-signal-externalization generate-certificates
make -C /root/go/src/github.com/gardener/k8s-playground/gardener-o11y-signal-externalization deploy-shoot 
```

```bash
# clean-up the gardener setup
make -C /root/go/src/github.com/gardener/gardener kind-down
```
