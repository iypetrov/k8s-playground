bootstrap:
	@kubectl create namespace ip812
	@kubectl create secret generic hcp-credentials \
		--namespace=ip812 \
	   	--from-literal=clientID=CLIENT_ID \
  		--from-literal=clientSecret=CLIENT_SECRET
	@helm repo add hashicorp https://helm.releases.hashicorp.com
	@helm install vault-secrets-operator hashicorp/vault-secrets-operator --namespace ip812
	@helm repo add traefik https://helm.traefik.io/traefik
	@helm install traefik traefik/traefik --namespace ip812 -f helm/traefik/values.yml
	@flux bootstrap github \
	    --token-auth=true \
	    --owner=iypetrov \
	    --repository=k8s-playground \
	    --branch=main \
	    --path=fluxcd-intro \
	    --read-write-key=true \
	    --personal=false \
	    --author-email=flux.bot@gmail.com \
	    --author-name=flux.bot \
	    --components-extra=image-automation-controller,image-reflector-controller
