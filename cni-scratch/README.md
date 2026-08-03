# cni-sceatch

## Overview
To enable networking, containers use a specialized virtual network interface called a **virtual ethernet (veth) device**. A veth pair consists of two connected interfaces:
- One interface is placed inside the container's **network namespace**.
- The other interface remains in the **host's network namespace**.
This configuration creates a communication link between the container and the host. As a result, containers running on the same node can communicate with one another through the host's networking stack.

The process of creating and configuring container networking is as follows:
- The _kube-apiserver_ communicates with the appropriate _kubelet_ on the target node.
- Rather than creating containers directly, the _kubelet_ delegates this responsibility to the Container Runtime Interface (CRI).
- The CRI creates the container and sets up its network namespace.
- After the network namespace has been created, the CRI invokes a **Container Network Interface (CNI)** plugin.
- The **CNI plugin** is responsible for:
    - Creating and configuring the virtual ethernet (veth) pair.
    - Connecting the container to the node's network.
	- Configuring the required routes and other networking settings.
> Please note that CNIs typically do not handle traffic forwarding or load balancing. By default, _kube-proxy_ serves as the default network proxy in Kubernetes which utilizes technologies like iptables or IPVS to direct incoming network traffic to the relevant Pods within the cluster. However, Cilium offers a superior alternative by loading eBPF programs directly into the kernel, achieving the same tasks with significantly higher speed. For more information on this topic see "[What is Kube-Proxy and why move from iptables to eBPF?](https://isovalent.com/blog/post/why-replace-iptables-with-ebpf/)".


## Getting Started Locally

### Start a KinD cluster locally with our CNI plugin + start a test Pod/Service
```bash
make kind-up cni-up test-pod plugin-logs
```

### Teardown the test cluster
```bash
make kind-down
```

## Implementation
These are the steps to create a custom CNI:
- After the CRI creates the network namespace, it loads the first configuration file found in `/etc/cni/net.d/`. We'll create `/etc/cni/net.d/10-foo.conf`, which contains a JSON configuration that follows the CNI specification. The field `"type": "foo"` tells the CRI to execute a CNI plugin named **foo** in the next step.
    ```json
    {
      "cniVersion": "1.0.0",
      "name": "fromScratch",
      "type": "foo"
    }
    ```
- The CRI looks for CNI plugin executables in `/opt/cni/bin/`, so we'll create a bash CNI plugin at `/opt/cni/bin/foo`. When the CRI invokes the plugin, it provides the CNI configuration JSON through STDIN and passes container-specific information, such as the target network namespace (`CNI_NETNS`), as environment variables.
    ```bash
    env | grep '^CNI_'
    # CNI_CONTAINERID=500f63fd2fb7138d6e6091d045acba028ef09a69544cf20a57651f0463e0676d
    # CNI_IFNAME=eth0
    # CNI_NETNS=/var/run/netns/cni-b614900b-6959-f366-3ca9-9925f755c389
    # CNI_COMMAND=ADD
    # CNI_PATH=/opt/cni/bin
    # CNI_ARGS=IgnoreUnknown=1;K8S_POD_NAMESPACE=default;K8S_POD_NAME=cni-test;K8S_POD_INFRA_CONTAINER_ID=500f63fd2fb7138d6e6091d045acba028ef09a69544cf20a57651f0463e0676d;K8S_POD_UID=1392598f-ac25-4f85-8778-0307f317028f
    ```
- The plugin's first task is to create a virtual Ethernet (veth) pair. A veth pair consists of two interconnected interfaces; we'll name them `veth_netns` and `veth_host` to make the following steps easier to understand.
    ```bash
    VETH_HOST=veth_host
    VETH_NETNS=veth_netns
    ip link add ${VETH_HOST} type veth peer name ${VETH_NETNS}
    ```
- Next, we'll move `veth_netns` into the container's network namespace. This creates a direct Layer 2 connection between the container's network namespace and the host's network namespace.
    ```bash
    NETNS=$(basename ${CNI_NETNS})
    ip link set ${VETH_NETNS} netns ${NETNS}
    ```
- Although both veth interfaces are automatically assigned MAC addresses, neither has an IP address. In a production environment, the container interface would receive an address from the node's Pod CIDR. For simplicity, we'll statically assign **10.244.0.20** to the interface inside the container and rename it according to the value of the `CNI_IFNAME` environment variable. This address becomes the Pod IP. In a real CNI implementation, IP allocation must ensure that every Pod receives a unique address to avoid routing conflicts.
    ```bash
    IP_VETH_NETNS=10.244.0.20
    ip -n ${NETNS} addr add ${IP_VETH_NETNS}/32 dev ${VETH_NETNS}
    ```
- The host-side interface, `veth_host`, will serve as the container's default gateway. We'll assign it the static IP address **10.244.0.101**. Unlike Pod IPs, this address can remain the same regardless of how many Pods are created, since its only purpose is to act as the next hop for traffic leaving the container.
    ```bash
    IP_VETH_HOST=10.244.0.101
    ip addr add ${IP_VETH_HOST}/32 dev ${VETH_HOST}
    ```
- As a chore we should rename veth interface inside the new network namespace to the `CNI_IFNAME` and enusre that all interfaces are up.
    ```bash
    # Rename veth interface inside the new network namespace.
    ip -n ${NETNS} link set ${VETH_NETNS} name ${CNI_IFNAME}
    
    # Ensure all interfaces are up.
    ip link set ${VETH_HOST} up
    ip -n ${NETNS} link set ${CNI_IFNAME} up
    ```
- With the interfaces configured, we'll add the required routes.
    - Inside the container's network namespace, we'll install a default route that forwards all traffic to **10.244.0.101** via the host-side veth.
        ```bash
        ip -n ${NETNS} route add ${IP_VETH_HOST} dev ${CNI_IFNAME}
        ip -n ${NETNS} route add default via ${IP_VETH_HOST} dev ${CNI_IFNAME}
        ```
    - On the host, we'll add a route directing traffic destined for **10.244.0.20** through `veth_host`. Together, these routes enable bidirectional communication between the container and the host.
        ```bash
        ip route add ${IP_VETH_NETNS}/32 dev ${VETH_HOST} scope host
        ```
- Finally, the plugin must report the result back to the CRI. It does this by writing a JSON document to STDOUT describing the network configuration it created, including the configured interfaces and assigned IP addresses.
    ```bash
    # Return a JSON via STDOUT.
    RETURN_TEMPLATE='
    {
      "cniVersion": "1.0.0",
      "interfaces": [
        {
          "name": "%s",
          "mac": "%s"
        },
        {
          "name": "%s",
          "mac": "%s",
          "sandbox": "%s"
        }
      ],
      "ips": [
        {
          "address": "%s",
          "interface": 1
        }
      ]
    }'
    
    MAC_HOST_VETH=$(ip link show ${VETH_HOST} | grep link | awk '{print$2}')
    MAC_NETNS_VETH=$(ip -netns $nsname link show ${CNI_IFNAME} | grep link | awk '{print$2}')
    
    RETURN=$(printf "${RETURN_TEMPLATE}" "${VETH_HOST}" "${MAC_HOST_VETH}" "${CNI_IFNAME}" "${MAC_NETNS_VETH}" "${CNI_NETNS}" "${IP_VETH_NETNS}/32")
    echo ${RETURN}
    ```

## References
- https://github.com/f1ko/demystifying-cni/blob/main/README.md
- https://github.com/containernetworking/cni/blob/main/SPEC.md
