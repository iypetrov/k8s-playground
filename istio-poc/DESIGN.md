# Design Doc: E2E TLS Encryption via Service Mesh on EKS

## Context

This document describes the migration from an AWS ALB-based ingress stack with certificates managed by ACM and Terraform, to a security-first architecture built around an AWS Network Load Balancer, cert-manager, and a service mesh. The goal is end-to-end TLS encryption — from the public internet all the way down to individual pods — with zero plaintext hops inside the cluster.

---

## The Problem with ALB + ACM

The previous setup relied on an AWS Application Load Balancer fronting the cluster, with TLS certificates provisioned and renewed via AWS Certificate Manager, wired up through Terraform.

This works well for basic HTTPS termination, but has a fundamental security gap: **TLS terminates at the ALB**. From that point, traffic between the ALB and the backend pods travels in plaintext over the VPC network. For regulated workloads or anything requiring defence-in-depth, this is a problem — a compromised node or a misconfigured security group is enough to read or tamper with in-flight traffic.

Additional friction with the ALB + ACM approach:

- Certificate lifecycle (issuance, rotation, revocation) is owned by Terraform state, meaning cert renewals require Terraform runs or careful drift management.
- ACM certificates are AWS-native and cannot be used directly inside the cluster for workload-to-workload TLS.
- The ALB operates at L7, which means SSL offload happens in the AWS data plane — no visibility into which workload originated the request.
- Scaling the setup across namespaces or clusters requires duplicating ACM/Terraform configuration.

---

## The Target Architecture: NLB + cert-manager + Service Mesh

The replacement stack shifts certificate ownership entirely into the cluster and uses a service mesh to enforce mTLS everywhere inside it.

**AWS Network Load Balancer (NLB)** replaces the ALB as the public entry point. The NLB operates at L4 and passes TLS connections straight through to the Istio ingress gateway without terminating them. This means the NLB never sees plaintext — it is purely a TCP passthrough. The health check is done over HTTP on the Istio readiness port (`15021`) so the NLB knows when the gateway is ready, without needing to understand TLS.

**cert-manager** takes over certificate lifecycle inside the cluster. It issues and rotates Let's Encrypt certificates automatically via a DNS-01 ACME challenge against Route 53, without any Terraform involvement. Certificates are stored as Kubernetes Secrets and consumed directly by the Istio ingress gateway. The 90-day rotation is handled autonomously — cert-manager renews 15 days before expiry, updates the Secret in place, and Istio picks up the new cert without any gateway restart.

**The service mesh** enforces mTLS for all traffic between workloads inside the cluster. Once a packet leaves the ingress gateway, it never travels in plaintext again.

The full traffic path:

```
Internet
  │  (TCP/TLS passthrough)
  ▼
AWS NLB (L4, no TLS termination)
  │  (HTTPS - cert issued by cert-manager / Let's Encrypt)
  ▼
Istio Ingress Gateway (TLS termination, path-based routing)
  │  (mTLS via HBONE tunnel)
  ▼
ztunnel (per-node, L4 mTLS enforcement)
  │  (HBONE + mTLS)
  ▼
Waypoint Proxy (per-namespace, L7 policy enforcement)
  │  (plaintext inside pod boundary only)
  ▼
Backend Pod
```

---

## Options Considered

Four approaches were evaluated for the service mesh layer. The decision was scoped to Kubernetes-native or Kubernetes-integrated solutions that could enforce mTLS transparently without requiring application changes.

### 1. Istio

The most mature and widely adopted service mesh. Supports both traditional sidecar injection and the newer ambient mode. Excellent L7 observability, rich traffic management primitives (VirtualService, DestinationRule, AuthorizationPolicy), and native Gateway API support. The CNCF graduation and large community reduce long-term risk. Ambient mode (released GA in Istio 1.24) directly addresses the historical overhead complaints around sidecar injection.

**Selected for this PoC and described in detail below.**

### 2. Linkerd

A simpler, lighter alternative to Istio. Uses a Rust-based micro-proxy (linkerd2-proxy) instead of Envoy, resulting in lower memory overhead per workload. The tradeoff is a narrower feature set — Linkerd focuses on reliability and mTLS but has less support for advanced traffic management and is slower to adopt new Kubernetes APIs (e.g. Gateway API support is more recent and less complete). Linkerd's ambient-equivalent ("no sidecar") story is not yet as mature as Istio's.

**Not selected:** feature set is insufficient for complex routing requirements, and the smaller ecosystem increases operational risk.

### 3. HashiCorp Consul Service Mesh

Consul has a strong multi-cluster and multi-runtime story — it works across VMs and containers, not just Kubernetes. This makes it attractive for hybrid environments. However, for a pure EKS setup it introduces significant operational overhead: Consul servers need to be managed, the control plane is separate from Kubernetes-native tooling, and the configuration model (intentions, config entries) diverges from Kubernetes APIs. Licensing changes in recent Consul versions (BSL) also create uncertainty.

**Not selected:** operational complexity without meaningful gain for a Kubernetes-only workload; licensing concerns.

### 4. AWS VPC Lattice

A fully managed AWS service that provides service-to-service connectivity and access control at the VPC layer, without running any mesh control plane. It integrates with the AWS Gateway API controller and can enforce policy based on IAM. The key limitation is that it is not a service mesh — it does not provide transparent mTLS between arbitrary pods, only between registered services that explicitly participate in a Lattice service network. Fine-grained L7 policy (retries, timeouts, header manipulation) is limited compared to Istio. There is also no concept of ambient or sidecar; security is enforced at the ENI/VPC level, not inside the cluster.

**Not selected:** not a true zero-trust mesh, limited L7 control, AWS lock-in, and no equivalent to automatic mTLS for east-west traffic.

---

## Istio Setup

### Ambient Mode vs Sidecar Mode

Istio's classical deployment model injects an Envoy sidecar container into every pod that joins the mesh. This works, but comes with real costs:

- **Resource overhead per pod:** each sidecar runs a full Envoy instance, consuming memory and CPU that scales linearly with pod count. In large clusters this adds up to significant waste.
- **Operational friction:** sidecar injection requires namespace or pod labelling and a rolling restart of all existing pods whenever Istio is upgraded.
- **Blast radius:** a sidecar bug or misconfiguration can crash the application container in the same pod.
- **Startup coupling:** the sidecar and application container share a pod lifecycle, causing init ordering issues and complicating graceful shutdown.

**Ambient mode** decouples the data plane from individual pods entirely. Instead of injecting a proxy into each pod, it runs two infrastructure components:

- **ztunnel** — a lightweight, per-node DaemonSet (written in Rust) that handles L4 mTLS. Every packet leaving or arriving at a pod on a node is intercepted by that node's ztunnel and wrapped in an HBONE (HTTP-Based Overlay Network Environment) tunnel with mTLS. This gives transparent encryption for all mesh traffic with zero per-pod overhead.
- **Waypoint proxy** — a standalone Envoy deployment that handles L7 concerns (routing, retries, header policies, AuthorizationPolicies based on JWT claims, etc.) for a given scope. Waypoints are opt-in and are only invoked when L7 processing is needed.

The result: mesh enrolment is a single label on a namespace. No pod restarts, no per-container resource overhead, no injection webhooks to worry about.

### Single Waypoint per Namespace

In sidecar mode, every pod runs its own Envoy. A request from service A to service B passes through A's egress sidecar, then through B's ingress sidecar — two full Envoy instances for a single hop. In a namespace with 20 services each scaled to 5 replicas, that is 200 sidecars.

Ambient mode's waypoint proxy collapses this. A single waypoint Envoy deployment per namespace handles all L7 traffic for every service in that namespace, regardless of replica count.

```yaml
# manifests/waypoint.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: waypoint
  namespace: poc
  labels:
    istio.io/waypoint-for: service
spec:
  gatewayClassName: istio-waypoint
  listeners:
    - name: mesh
      port: 15008
      protocol: HBONE
```

The namespace is then labelled to declare mesh enrolment and point to the waypoint:

```yaml
# manifests/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: poc
  labels:
    istio.io/dataplane-mode: ambient
    istio.io/use-waypoint: waypoint
```

`istio.io/dataplane-mode: ambient` opts all pods in the namespace into ztunnel-based L4 mTLS. `istio.io/use-waypoint: waypoint` tells Istio that L7 policies for this namespace should be enforced through the `waypoint` Gateway. Istio deploys one Envoy pod for the waypoint; all service-to-service traffic in the namespace routes through it.

**Why this is better than sidecar-per-pod:**

| | Sidecar mode | Ambient + single waypoint |
|---|---|---|
| Envoys per 100-pod namespace | 100 | 1 (waypoint) + 1 per node (ztunnel) |
| Pod restart required on mesh join | Yes | No |
| Upgrade requires pod rollout | Yes | No (ztunnel/waypoint updated independently) |
| L4 mTLS | Envoy in pod | ztunnel on node |
| L7 policy | Envoy in pod | Centralised waypoint |
| Failure isolation | Sidecar crash → pod unhealthy | Waypoint crash → L7 policy bypassed, L4 still enforced |

The centralised waypoint also makes L7 policy easier to reason about — there is one place to look for routing rules and AuthorizationPolicies for a namespace, rather than configuration spread across hundreds of sidecar instances.

### Istio Gateway and TLS Termination

The ingress gateway is deployed as a separate Helm release (`istio/gateway`) in its own `istio-ingress` namespace, with the NLB wired up through service annotations:

```yaml
# values/ingress-values.yaml
service:
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "external"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-port: "15021"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/healthz/ready"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol: "HTTP"
  ports:
    - name: https
      port: 443
      targetPort: 8443
```

`nlb-target-type: ip` instructs the AWS Load Balancer Controller to register pod IPs directly (rather than node ports), which reduces one network hop and keeps health checks accurate per-pod. The NLB forwards port 443 to port 8443 on the gateway pod — this is where Envoy listens for HTTPS.

TLS is configured through an Istio `Gateway` resource that references a Kubernetes Secret populated by cert-manager:

```yaml
# manifests/istio-gateway.yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: app-gateway
  namespace: istio-ingress
spec:
  selector:
    istio: ingress          # targets pods with label istio=ingress (the gateway deployment)
  servers:
    - hosts:
        - "app.ip812.click"
      tls:
        mode: SIMPLE         # one-way TLS: server presents cert, client validates
        credentialName: app-ip812-click-tls   # Kubernetes Secret name
      port:
        number: 443
        name: https
        protocol: HTTPS
```

`credentialName` tells the gateway to read the TLS certificate and private key from the `app-ip812-click-tls` Secret, which cert-manager owns and rotates. When cert-manager renews the certificate (15 days before the 90-day expiry), it updates the Secret and Istio's SDS (Secret Discovery Service) watches for the change and reloads the certificate without any gateway restart.

The cert-manager `Certificate` resource requests a Let's Encrypt certificate using a DNS-01 challenge against Route 53 — no HTTP challenge, no need for the domain to be publicly reachable over port 80 during issuance:

```yaml
# manifests/certificates.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: app-ip812-click
  namespace: istio-ingress      # must be in the same namespace as the Gateway
spec:
  secretName: app-ip812-click-tls
  duration: 2160h               # 90 days
  renewBefore: 360h             # renew 15 days before expiry
  dnsNames:
    - app.ip812.click
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
```

Routing from the gateway to backend services is declared in a `VirtualService` that binds to the gateway and maps URI prefixes to Kubernetes services:

```yaml
# manifests/istio-gateway.yaml (VirtualService)
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: nginx-route
  namespace: poc
spec:
  hosts:
    - "app.ip812.click"
  gateways:
    - istio-ingress/app-gateway   # cross-namespace reference: <namespace>/<gateway-name>
  http:
    - match:
        - uri:
            prefix: /red
      rewrite:
        uri: /
      route:
        - destination:
            host: red.poc.svc.cluster.local
            port:
              number: 80
    - match:
        - uri:
            prefix: /green
      ...
```

The `gateways` field uses a namespaced reference (`istio-ingress/app-gateway`) to pull traffic from the gateway in the `istio-ingress` namespace into routing rules that target services in the `poc` namespace. The URI rewrite strips the path prefix before forwarding, so backends receive requests at `/` regardless of which path was used externally.

Once the request leaves the gateway and enters the `poc` namespace, ztunnel on each node wraps the connection in mTLS automatically. If the destination service has a waypoint, the traffic routes through it for L7 policy enforcement before reaching the pod. No application code changes, no certificate management inside the application — the mesh handles it all transparently.

---

## Summary

| Concern | Old (ALB + ACM + Terraform) | New (NLB + cert-manager + Istio ambient) |
|---|---|---|
| TLS termination point | ALB (outside cluster) | Istio ingress gateway (inside cluster) |
| In-cluster encryption | None (plaintext) | mTLS everywhere via ztunnel |
| Certificate ownership | Terraform / ACM | cert-manager / Let's Encrypt |
| Certificate rotation | Manual Terraform run or ACM auto-renew with no in-cluster visibility | Autonomous, Secret-based, watched by Istio SDS |
| Per-pod overhead | None (no mesh) | ztunnel on node only (no per-pod sidecar) |
| L7 policy enforcement | ALB listener rules | Istio VirtualService + waypoint Envoy |
| Zero-trust posture | No (ALB-to-pod is plaintext) | Yes (mTLS enforced for all pod-to-pod traffic) |
