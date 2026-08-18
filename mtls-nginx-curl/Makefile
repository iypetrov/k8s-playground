CLUSTER_NAME?=mtls-nginx-curl
CERT_DIR?=certs

.PHONY: kind-up
kind-up:
	@kind create cluster --config kind.yaml --name ${CLUSTER_NAME}

.PHONY: kind-down
kind-down:
	@kind delete cluster --name ${CLUSTER_NAME}

.PHONY: generate-certificates
generate-certificates:
	@chmod +x scripts/generate-certificates.sh && bash scripts/generate-certificates.sh
	@echo "Creating nginx server TLS secret..."
	@kubectl create secret generic nginx-tls \
		--from-file=tls.crt=$(CERT_DIR)/nginx-server.crt \
		--from-file=tls.key=$(CERT_DIR)/nginx-server.key \
		--from-file=ca.crt=$(CERT_DIR)/ca.crt \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "Creating curl client TLS secret..."
	@kubectl create secret generic curl-client-tls \
		--from-file=client.crt=$(CERT_DIR)/curl-client.crt \
		--from-file=client.key=$(CERT_DIR)/curl-client.key \
		--from-file=ca.crt=$(CERT_DIR)/ca.crt \
		--dry-run=client -o yaml | kubectl apply -f -

.PHONY: generate-dummy-cert
generate-dummy-cert:
	@chmod +x scripts/generate-dummy-cert.sh && bash scripts/generate-dummy-cert.sh
	@echo "Creating dummy (untrusted) client TLS secret..."
	@kubectl create secret generic dummy-client-tls \
		--from-file=client.crt=$(CERT_DIR)/dummy-client.crt \
		--from-file=client.key=$(CERT_DIR)/dummy-client.key \
		--dry-run=client -o yaml | kubectl apply -f -

.PHONY: mtls-up
mtls-up:
	@helm repo add stakater https://stakater.github.io/stakater-charts
	@helm repo update
	@helm upgrade --install reloader stakater/reloader \
	  --namespace reloader \
	  --create-namespace
	@kubectl apply -k k8s/
