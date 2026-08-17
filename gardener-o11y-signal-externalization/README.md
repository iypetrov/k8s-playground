```bash
export KUBECONFIG_VIRTUAL=/root/go/src/github.com/gardener/gardener/dev-setup/kubeconfigs/virtual-garden/kubeconfig
export KUBECONFIG_RUNTIME=/root/go/src/github.com/gardener/gardener/dev-setup/kubeconfigs/runtime/kubeconfig
export KUBECONFIG=$KUBECONFIG_RUNTIME
export KUBECONFIG_SHOOT=/root/go/src/github.com/gardener/gardener/dev-setup/kubeconfigs/shoot/kubeconfig
alias kr="kubectl --kubeconfig $KUBECONFIG_RUNTIME"
alias kv="kubectl --kubeconfig $KUBECONFIG_VIRTUAL"
alias ks="kubectl --kubeconfig $KUBECONFIG_SHOOT"

# run gardener locally
make -C /root/go/src/github.com/gardener/gardener kind-up gardener-up

# deploy the otelcol extesnion
make -C /root/go/src/github.com/gardener/gardener-extension-otelcol deploy-operator

# create a shoot cluster
make -C /root/go/src/github.com/gardener/k8s-playground/gardener-o11y-signal-externalization deploy-base-shoot 
KUBECONFIG=$KUBECONFIG_VIRTUAL bash /root/go/src/github.com/gardener/gardener/hack/usage/generate-kubeconfig.sh shoot > $KUBECONFIG_SHOOT

# generate certificates + deploy the extesnion on the shoot
make -C /root/go/src/github.com/gardener/k8s-playground/gardener-o11y-signal-externalization generate-certificates
make -C /root/go/src/github.com/gardener/k8s-playground/gardener-o11y-signal-externalization deploy-shoot 

# deploy shoot's o11y stacks on the dataplane
make -C /root/go/src/github.com/gardener/k8s-playground/gardener-o11y-signal-externalization o11y-receiver
```

```bash
# clean-up the gardener setup
make -C /root/go/src/github.com/gardener/gardener kind-down
```
