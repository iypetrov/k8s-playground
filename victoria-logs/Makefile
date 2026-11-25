CLUSTER_NAME?=victoria-logs

.PHONY: kind-up
kind-up:
	@kind create cluster --config kind.yaml --name ${CLUSTER_NAME}

.PHONY: kind-down
kind-down:
	@kind delete cluster --name ${CLUSTER_NAME}

.PHONY: victoria-up
victoria-up:
	@kubectl apply -f manifest.yaml

.PHONY: victoria-down
victoria-down:
	@kubectl delete -f manifest.yaml

.PHONY: victoria-port-forward
victoria-port-forward:
	@kubectl port-forward -n victoria svc/vlsingle 9428:9428
