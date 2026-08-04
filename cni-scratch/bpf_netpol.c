#include <linux/bpf.h>
#include <linux/pkt_cls.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

SEC("tc")
int tc_block_ingress(struct __sk_buff *skb)
{
  const __be32 pod_ip = 0x0AF40014; // 10.244.0.20

  void *data = (void *)(long)skb->data;
  void *data_end = (void *)(long)skb->data_end;

  // Satisfy verifier.
  struct ethhdr *eth = data;
  if ((void *)(eth + 1) > data_end)
    return TC_ACT_OK;

  // Only inspect IPv4 packets, let everything else pass.
  if (eth->h_proto != __bpf_htons(ETH_P_IP))
    return TC_ACT_OK;

  struct iphdr *ip = (void *)(eth + 1);
  if ((void *)(ip + 1) > data_end)
    return TC_ACT_OK;

  // Drop anything headed for the pod IP.
  if (ip->daddr == __bpf_htonl(pod_ip))
    return TC_ACT_SHOT;

  return TC_ACT_OK;
}

char LICENSE[] SEC("license") = "GPL";
