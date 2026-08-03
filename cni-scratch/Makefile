CLUSTER_NAME?=cni-scratch-foo

.PHONY: kind-up
kind-up:
	kind create cluster --config kind.yaml --name ${CLUSTER_NAME}
	kubectl delete deploy -n kube-system coredns
	kubectl delete deploy -n local-path-storage local-path-provisioner

.PHONY: kind-down
kind-down:
	kind delete cluster --name ${CLUSTER_NAME}

.PHONY: cni-up
cni-up:
	docker cp 10-foo.conf ${CLUSTER_NAME}-control-plane:/etc/cni/net.d/10-foo.conf
	docker cp foo.sh ${CLUSTER_NAME}-control-plane:/opt/cni/bin/foo
	docker exec ${CLUSTER_NAME}-control-plane chmod +x /opt/cni/bin/foo
	docker build -f Dockerfile.foo -t cni-scratch:foo .
	kind load docker-image cni-scratch:foo --name ${CLUSTER_NAME}
	kubectl apply -f cni-daemonset.yaml
	kubectl rollout status daemonset/foo-cni -n kube-system --timeout=90s

.PHONY: app 
app:
	kubectl run cni-test --image=httpd
	kubectl create svc clusterip cni-test --clusterip 10.96.0.100 --tcp=80:80

.PHONY: cni-logs
cni-logs:
	docker exec ${CLUSTER_NAME}-control-plane sh -c 'for i in $$(seq 1 30); do [ -f /var/log/foo-cni.log ] && break; sleep 1; done; tail -f /var/log/foo-cni.log'

.PHONY: validate-pod-connectivity
validate-pod-connectivity:
	docker exec ${CLUSTER_NAME}-control-plane curl -s 10.244.0.20

.PHONY: bpf-prepare
bpf-prepare:
	docker exec ${CLUSTER_NAME}-control-plane apt update -y > /dev/null
	docker exec ${CLUSTER_NAME}-control-plane apt install -y clang llvm libbpf-dev libelf-dev gcc make bpftool > /dev/null
	docker exec ${CLUSTER_NAME}-control-plane ln -s /usr/include/aarch64-linux-gnu/asm /usr/include/asm || true

.PHONY: bpf-prepare-kpr
bpf-prepare-kpr:
	docker cp bpf_kpr.c ${CLUSTER_NAME}-control-plane:/root/bpf_kpr.c
	docker exec ${CLUSTER_NAME}-control-plane clang -O2 -g -target bpf -Wall -c /root/bpf_kpr.c -o /root/bpf_kpr.o
	docker exec ${CLUSTER_NAME}-control-plane bpftool prog load /root/bpf_kpr.o /sys/fs/bpf/sock4_connect
	docker exec ${CLUSTER_NAME}-control-plane bpftool cgroup attach /sys/fs/cgroup connect4 pinned /sys/fs/bpf/sock4_connect

.PHONY: bpf-clean-kpr
bpf-clean-kpr:
	docker exec ${CLUSTER_NAME}-control-plane bpftool cgroup detach /sys/fs/cgroup connect4 pinned /sys/fs/bpf/sock4_connect
	docker exec ${CLUSTER_NAME}-control-plane rm /sys/fs/bpf/sock4_connect

.PHONY: validate-service-connectivity
validate-service-connectivity:
	docker exec ${CLUSTER_NAME}-control-plane curl -s 10.96.0.100
