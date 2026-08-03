CLUSTER_NAME?=cni-scratch-foo

.PHONY: kind-up
kind-up:
	kind create cluster --config kind.yaml --name ${CLUSTER_NAME}
	kubectl delete deploy -n kube-system coredns
	kubectl delete deploy -n local-path-storage local-path-provisioner

.PHONY: cni-up
cni-up:
	docker cp 10-foo.conf ${CLUSTER_NAME}-control-plane:/etc/cni/net.d/10-foo.conf
	docker cp foo.sh ${CLUSTER_NAME}-control-plane:/opt/cni/bin/foo
	docker exec ${CLUSTER_NAME}-control-plane chmod +x /opt/cni/bin/foo
	docker build -f Dockerfile.foo -t cni-scratch:foo .
	kind load docker-image cni-scratch:foo --name ${CLUSTER_NAME}
	kubectl apply -f cni-daemonset.yaml
	kubectl rollout status daemonset/foo-cni -n kube-system --timeout=90s

.PHONY: test-pod
test-pod:
	kubectl run cni-test --image=httpd

.PHONY: plugin-logs
plugin-logs:
	docker exec ${CLUSTER_NAME}-control-plane sh -c 'for i in $$(seq 1 30); do [ -f /var/log/foo-cni.log ] && break; sleep 1; done; tail -f /var/log/foo-cni.log'

.PHONY: kind-down
kind-down:
	kind delete cluster --name ${CLUSTER_NAME}
