useful links:
- https://developer.hashicorp.com/hcp/tutorials/get-started-hcp-vault-secrets/hcp-vault-secrets-kubernetes-vso
- https://www.youtube.com/watch?v=ECa8sAqE7M4

- Add the HashiCorp Helm repository
```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
```

- Install the Vault Secrets Operator
```bash
helm install vault-secrets-operator hashicorp/vault-secrets-operator \
     --namespace vault \
     --create-namespace
```

- Create a few secrets manually
```bash
kubectl create secret generic hcp-credentials \
  --namespace vault \
  --from-literal=clientID=<HCP_CLIENT_ID> \
  --from-literal=clientSecret=<HCP_CLIENT_SECRET>
```

Useful for debugging:
```bash
kubectl describe hcpvaultsecretsapp vault-secrets-app -n vault
```
