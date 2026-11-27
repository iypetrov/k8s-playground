This directory contains the setup required to validate Go auto-instrumentation and reproduce the issue described in https://github.com/open-telemetry/opentelemetry-operator/issues/4539.

```bash
# Run the otel-operator locally (run this from the otel-operator directory).
make start-kind install cert-manager prepare-e2e run

# Enable Go auto-instrumentation.
kubectl patch deployment opentelemetry-operator-controller-manager \
    -n opentelemetry-operator-system \
    --type=json \
    -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--enable-go-instrumentation=true"}]'
kubectl rollout restart -n opentelemetry-operator-system deployment/opentelemetry-operator-controller-manager

# Load needed Docker images into KinD cluster.
make -C http-server docker-build
make -C batch-job docker-build
make kind-load

# Deploy testing Deployment and CronJob written in Go to validate Go auto-instrumentation.
# This also deploys Jaeger instance with memory storage to collect auto-generated traces.
make apply

# Port forward to the Jaeger UI to see the ingestion data.
make jaeger-ui
```

Before the fix:
```bash
$ kubectl get pods -A
NAMESPACE                       NAME                                                         READY   STATUS     RESTARTS   AGE
batch-job                       batch-job-29929428-rxvcq                                     1/2     NotReady   0          4m35s
batch-job                       batch-job-29929429-n4t2z                                     1/2     NotReady   0          3m35s
batch-job                       batch-job-29929430-jjz75                                     1/2     NotReady   0          2m35s
batch-job                       batch-job-29929431-rjk6z                                     1/2     NotReady   0          95s
batch-job                       batch-job-29929432-6ftjg                                     1/2     NotReady   0          35s
cert-manager                    cert-manager-6b4c965758-nwmsf                                1/1     Running    0          17m
cert-manager                    cert-manager-cainjector-cfb87477-tjkz4                       1/1     Running    0          17m
cert-manager                    cert-manager-webhook-6cd8d5f8d9-2pv88                        1/1     Running    0          17m
http-server                     http-server-59bd99876d-bjx5x                                 2/2     Running    0          3m5s
kube-system                     coredns-559f6c778d-kvbtf                                     1/1     Running    0          17m
kube-system                     coredns-559f6c778d-lczgg                                     1/1     Running    0          17m
kube-system                     etcd-otel-operator-control-plane                             1/1     Running    0          18m
kube-system                     kindnet-kcnmm                                                1/1     Running    0          17m
kube-system                     kube-apiserver-otel-operator-control-plane                   1/1     Running    0          18m
kube-system                     kube-controller-manager-otel-operator-control-plane          1/1     Running    0          18m
kube-system                     kube-proxy-b9w9q                                             1/1     Running    0          17m
kube-system                     kube-scheduler-otel-operator-control-plane                   1/1     Running    0          18m
kube-system                     metrics-server-76558b4bb9-6n4v5                              1/1     Running    0          17m
local-path-storage              local-path-provisioner-75f7fc7dc5-d9w7g                      1/1     Running    0          17m
opentelemetry-operator-system   opentelemetry-operator-controller-manager-6d8b796b5d-4qb2s   1/1     Running    0          2m20s
receiver                        auto-instrumentation-receiver-collector-745dd766b4-mdcbk     1/1     Running    0          4m45s
```

After the fix:
```bash
$ kubectl get pods -A
NAMESPACE                       NAME                                                         READY   STATUS      RESTARTS   AGE
batch-job                       batch-job-29929445-76qdc                                     0/2     Completed   0          2m43s
batch-job                       batch-job-29929446-5r7l9                                     0/2     Completed   0          103s
batch-job                       batch-job-29929447-9rkkt                                     0/2     Completed   0          43s
cert-manager                    cert-manager-6b4c965758-grcw6                                1/1     Running     0          8m26s
cert-manager                    cert-manager-cainjector-cfb87477-nwwjf                       1/1     Running     0          8m26s
cert-manager                    cert-manager-webhook-6cd8d5f8d9-lxx8l                        1/1     Running     0          8m26s
http-server                     http-server-7bf97699f7-t5kvv                                 2/2     Running     0          5m17s
kube-system                     coredns-559f6c778d-2dkjw                                     1/1     Running     0          8m26s
kube-system                     coredns-559f6c778d-prkfv                                     1/1     Running     0          8m26s
kube-system                     etcd-otel-operator-control-plane                             1/1     Running     0          8m34s
kube-system                     kindnet-9v9bj                                                1/1     Running     0          8m26s
kube-system                     kube-apiserver-otel-operator-control-plane                   1/1     Running     0          8m34s
kube-system                     kube-controller-manager-otel-operator-control-plane          1/1     Running     0          8m34s
kube-system                     kube-proxy-brz24                                             1/1     Running     0          8m26s
kube-system                     kube-scheduler-otel-operator-control-plane                   1/1     Running     0          8m34s
kube-system                     metrics-server-76558b4bb9-hprgb                              1/1     Running     0          7m50s
local-path-storage              local-path-provisioner-75f7fc7dc5-qj9m6                      1/1     Running     0          8m26s
opentelemetry-operator-system   opentelemetry-operator-controller-manager-59bd547787-m4d8p   1/1     Running     0          6m16s
receiver                        auto-instrumentation-receiver-collector-745dd766b4-sb6p5     1/1     Running     0          5m17s
```
