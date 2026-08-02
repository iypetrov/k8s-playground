# cni-sceatch

## Overview
These are the steps to create a custom CNI:
- After the CRI creates the network namespace, it loads the first configuration file found in `/etc/cni/net.d`. We'll create `/etc/cni/net.d/10-foo.conf`, which contains a JSON configuration that follows the CNI specification. The field `"type": "foo"` tells the CRI to execute a CNI plugin named **foo** in the next step.
```json
{
  "cniVersion": "1.0.0",
  "name": "fromScratch",
  "type": "foo"
}
```
- The CRI looks for CNI plugin executables in `/opt/cni/bin`, so we'll create a bash CNI plugin at `/opt/cni/bin/foo`. When the CRI invokes the plugin, it provides the CNI configuration JSON through STDIN and passes container-specific information, such as the target network namespace (`CNI_NETNS`), as environment variables.
```bash
# foo.sh

export -p

# $ make docker-build docker-run

```


- The plugin's first task is to create a virtual Ethernet (veth) pair. A veth pair consists of two interconnected interfaces; we'll name them veth_netns and veth_host to make the following steps easier to understand.
- Next, we'll move veth_netns into the container's network namespace. This creates a direct Layer 2 connection between the container's network namespace and the host's network namespace.
- Although both veth interfaces are automatically assigned MAC addresses, neither has an IP address. In a production environment, the container interface would receive an address from the node's Pod CIDR. For simplicity, we'll statically assign 10.244.0.20 to the interface inside the container and rename it according to the value of the CNI_IFNAME environment variable. This address becomes the Pod IP. In a real CNI implementation, IP allocation must ensure that every Pod receives a unique address to avoid routing conflicts.
- The host-side interface, veth_host, will serve as the container's default gateway. We'll assign it the static IP address 10.244.0.101. Unlike Pod IPs, this address can remain the same regardless of how many Pods are created, since its only purpose is to act as the next hop for traffic leaving the container.
- With the interfaces configured, we'll add the required routes. Inside the container's network namespace, we'll install a default route that forwards all traffic to 10.244.0.101 via the host-side veth. On the host, we'll add a route directing traffic destined for 10.244.0.20 through veth_host. Together, these routes enable bidirectional communication between the container and the host.
- Finally, the plugin must report the result back to the CRI. It does this by writing a JSON document to STDOUT describing the network configuration it created, including the configured interfaces and assigned IP addresses.

## References
- https://github.com/f1ko/demystifying-cni/blob/main/README.md
- https://github.com/containernetworking/cni/blob/main/SPEC.md
