what is the flow (go to the k8s-playground/gardener-o11y-signals-externalization)

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
make -C ../gardener kind-up gardener-up

# deploy the otelcol extesnion (gardener-extension-otelcol)
make -C ../gardener-extension-otel-col deploy-operator

# create the shoot cluster (this)
make deploy-shoot 
KUBECONFIG=$KUBECONFIG_VIRTUAL bash /root/go/src/github.com/gardener/gardener/hack/usage/generate-kubeconfig.sh shoot > $KUBECONFIG_SHOOT

# deploy shoot's testing o11y stacks
make o11y-receiver

# generate certificates + deploy the shoot
make generate-certificates
make deploy-shoot 
```

```bash
make -C ../gardener kind-down
```
