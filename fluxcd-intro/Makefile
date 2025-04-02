bootstrap:
	@helm repo add hashicorp https://helm.releases.hashicorp.com
	@helm install vault-secrets-operator hashicorp/vault-secrets-operator --namespace ip812 --create-namespace
	@kubectl create secret generic hcp-credentials \
		--namespace=ip812 \
	 	--from-literal=clientID=CLIENT_ID \
     	--from-literal=clientSecret=CLIENT_SECRET 
	@flux bootstrap github \
		--token-auth=true \
		--owner=iypetrov \
		--repository=k8s-playground \
		--branch=main \
		--path=fluxcd-intro \
		--read-write-key=true \
		--personal=false \
		--author-email=bot.fluxcd@gmail.com \
		--author-name="FluxCD [BOT]" \	
		--components-extra=image-automation-controller,image-reflector-controller
