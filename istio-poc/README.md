# Istio PoC

### Bootstrap

```bash
kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
  kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/experimental-install.yaml

helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

helm install istio-base istio/base \
  -n istio-system \
  --create-namespace \
  --wait \
  --version 1.29.0

helm install istiod istio/istiod \
  -n istio-system \
  --set profile=ambient \
  --wait \
  --version 1.29.0

helm install istio-cni istio/cni \
  -n istio-system \
  --set profile=ambient \
  --wait \
  --version 1.29.0

helm install ztunnel istio/ztunnel \
  -n istio-system \
  --wait \
  --version 1.29.0

helm install istio-ingress istio/gateway \
  -n istio-ingress \
  --create-namespace \
  -f values/ingress-values.yaml \
  --wait \
  --version 1.29.0
```

### Overview

This PoC runs Istio in **ambient mode** on EKS, demonstrating end-to-end encrypted traffic from the public internet all the way to backend pods — with no sidecars required.

External traffic enters through an AWS **Network Load Balancer** (NLB), which forwards HTTPS connections to the Istio ingress gateway. TLS certificates are provisioned and rotated automatically by **cert-manager**, using Let's Encrypt via a DNS-01 challenge against Route 53. The ingress gateway terminates TLS and applies path-based routing rules to dispatch requests to the appropriate backend service.

Inside the cluster, traffic stays encrypted thanks to Istio's **ambient data plane**. Rather than injecting a sidecar into every pod, ambient mode uses a per-node `ztunnel` to transparently handle mTLS between workloads at Layer 4. For Layer 7 concerns — traffic policies, header manipulation, fine-grained routing — a **waypoint proxy** is deployed per namespace and all mesh traffic for that namespace passes through it. This gives full L7 observability and control without the overhead of sidecar injection.

```
Internet → NLB → Istio Ingress Gateway (TLS termination, path-based routing) → ztunnel (mTLS) → Waypoint (L7 policy) → backend pods
```

### References

- https://istio.io/latest/docs/ambient/architecture/

- https://oneuptime.com/blog/post/2026-02-24-how-to-configure-istio-with-aws-nlb/view

- https://istio.io/latest/docs/ambient/usage/waypoint/
