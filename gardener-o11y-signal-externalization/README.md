```bash
export KUBECONFIG_VIRTUAL=/home/iypetrov/projects/oss/gardener-gardener/dev-setup/kubeconfigs/virtual-garden/kubeconfig
export KUBECONFIG_RUNTIME=/home/iypetrov/projects/oss/gardener-gardener/dev-setup/kubeconfigs/runtime/kubeconfig
export KUBECONFIG_SHOOT=/home/iypetrov/projects/oss/gardener-gardener/admin-kubeconf.yaml
export KUBECONFIG=$KUBECONFIG_RUNTIME
# export CLOUDFLARED_TUNNEL_TOKEN=YOUR_TOKEN
alias kr="kubectl --kubeconfig $KUBECONFIG_RUNTIME"
alias kv="kubectl --kubeconfig $KUBECONFIG_VIRTUAL"
alias ks="kubectl --kubeconfig $KUBECONFIG_SHOOT"

# run gardener locally
make -C /home/iypetrov/projects/oss/gardener-gardener kind-up gardener-up

# deploy the otelcol extesnion
make -C /home/iypetrov/projects/oss/gardener-gardener-extension-otelcol deploy-operator

# create a shoot cluster
make -C /home/iypetrov/projects/personal/k8s-playground/gardener-o11y-signal-externalization deploy-base-shoot
until [[ "$(kubectl --kubeconfig $KUBECONFIG_VIRTUAL get shoots -n garden-local -o json | jq -r 'any(.items[]; .metadata.name == "local" and .status.lastOperation.progress == 100)')" == "true" ]]; do
    echo "waiting for shoot 'local' to reconcile..." && sleep 10
done
KUBECONFIG=$KUBECONFIG_VIRTUAL bash /home/iypetrov/projects/oss/gardener-gardener/hack/usage/generate-kubeconfig.sh shoot > $KUBECONFIG_SHOOT

# generate certificates + deploy the extesnion on the shoot
make -C /home/iypetrov/projects/personal/k8s-playground/gardener-o11y-signal-externalization generate-certificates
make -C /home/iypetrov/projects/personal/k8s-playground/gardener-o11y-signal-externalization deploy-shoot

# deploy shoot's o11y stacks on the dataplane
make -C /home/iypetrov/projects/personal/k8s-playground/gardener-o11y-signal-externalization o11y-receiver
```

```bash
# clean-up the gardener setup
make -C /home/iypetrov/projects/oss/gardener-gardener kind-down
```
