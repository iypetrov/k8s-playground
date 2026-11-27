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
