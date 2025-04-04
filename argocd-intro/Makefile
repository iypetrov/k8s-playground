bootstrap:
	@kubectl create namespace ip812
	@kubectl create namespace argocd
	@kubectl create secret generic hcp-credentials \
		--namespace=ip812 \
	   	--from-literal=clientID=CLIENT_ID \
  		--from-literal=clientSecret=CLIENT_SECRET
	@helm repo add hashicorp https://helm.releases.hashicorp.com
	@helm install vault-secrets-operator hashicorp/vault-secrets-operator -n ip812
	@helm repo add traefik https://helm.traefik.io/traefik
	@helm install traefik traefik/traefik -n ip812 -f values/traefik.yml
	@helm repo add argo https://argoproj.github.io/argo-helm
	@helm install updater -n argocd argo/argocd-image-updater -f values/image-updater.yaml
	@kubectl create secret generic argocd-notifications-secret \
  		--namespace=argocd \
  		--from-literal=slack-token="SLACK_TOKEN"
	@helm install argocd --namespace argocd -f values/argocd.yml argo/argo-cd

argocd-init-pass:
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 

apply:
	@kubectl apply -f ./manifests/ --recursive
