what is the flow

```bash
# run gardener locally (gardener)
make kind-up gardener-u[

# deploy the otelcol extesnion (gardener-extension-otelcol)
make deploy-operator

# create the shoot cluster (this)
make deploy-shoot 
KUBECONFIG=$KUBECONFIG_VIRTUAL bash /root/go/src/github.com/gardener/gardener/hack/usage/generate-kubeconfig.sh shoot > $KUBECONFIG_SHOOT

# deploy shoot's testing o11y stacks
make o11y-receiver

# login to hyperdx and create account
# copy the hyperdx auth token and put it as a refs data in the shoot spec
make sync-hyperdx-api-key
make deploy-shoot 
```
