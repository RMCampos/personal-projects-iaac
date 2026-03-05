# Google Connect IPV4 changes needed

Get cluster CIDR:

```bash
kubectl cluster-info dump | grep -m1 cluster-cidr
```

Then, add ufw rules to allow ipv4 traffic:

```bash
sudo ufw route allow from 10.42.0.0/24 to any port 443 proto tcp
sudo ufw route allow from 10.42.0.0/24 to any port 80 proto tcp
sudo ufw reload
```

Flannel redunes MTU to 1450 but pods reported 1500, causing large packets (TLS handshake) to be silently dropped.
Add to `before.rules` before the *filter block:

```
*mangle
:FORWARD ACCEPT [0:0]
-A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
COMMIT
```

Then run `sudo ufw reload`

Pods have no IPv6 egress, but undici (Next.js's fetch) uses Happy Eyeballs and tries IPv6 first, timing out silently. Add to the .:53 block in the CoreDNS ConfigMap:

```
template IN AAAA . {
    rcode NXDOMAIN
}
```

Then apply with:

```bash
kubectl edit configmap coredns -n kube-system
kubectl rollout restart deployment/coredns -n kube-system
```
