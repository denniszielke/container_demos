# Cillium

## Install
https://docs.cilium.io/en/v1.6/gettingstarted/k8s-install-aks/

```
kubectl apply -f cillium/cillium-cm.yaml

curl -sL https://github.com/cilium/cilium/archive/v1.6.tar.gz | tar xz
curl -sL https://github.com/cilium/cilium/archive/v1.6.4.tar.gz | tar xz

cd cilium-1.6/install/kubernetes

helm template cilium \
  --namespace cilium \
  --set global.cni.chainingMode=generic-veth \
  --set global.cni.customConf=true \
  --set global.nodeinit.enabled=true \
  --set global.cni.configMap=cni-configuration \
  --set global.tunnel=disabled \
  --set global.masquerade=false \
  > cilium.yaml
kubectl create -f cilium.yaml

kubectl -n kube-system get pods --watch
```

deploy connectivity set
```
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/v1.6/examples/kubernetes/connectivity-check/connectivity-check.yaml

kubectl logs -l name=echo
kubectl logs -l name=probe
```

## Configure DNS lockdown

https://docs.cilium.io/en/v1.6/gettingstarted/dns/


cat <<EOF | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "fqdn"
spec:
  endpointSelector:
    matchLabels:
      sec: allow
  egress:
  - toFQDNs:
    - matchName: "ipinfo.io"  
    toPorts:
    - ports:
      - port: "443"
        protocol: TCP
  - toEndpoints:
    - matchLabels:
        "k8s:k8s-app": kube-dns
    toPorts:
    - ports:
      - port: "53"
        protocol: ANY
      rules:
        dns:
        - matchPattern: "*"
EOF

kubectl delete CiliumNetworkPolicy fqdn

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: centos1
  labels:
    sec: allow
spec:
  containers:
  - name: centos
    image: centos
    ports:
    - containerPort: 80
    command:
    - sleep
    - "3600"
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: centos2
  labels:
    sec: lock
spec:
  containers:
  - name: centos
    image: centos
    ports:
    - containerPort: 80
    command:
    - sleep
    - "3600"
EOF

kubectl exec -it centos1 -- curl https://ipinfo.io/ip
kubectl exec -it centos1 -- curl https://ifconfig.co/ip
kubectl exec -it centos2 -- curl https://ipinfo.io/ip
kubectl exec -it centos2 -- curl https://ifconfig.co/ip

kubectl delete pod centos1
kubectl delete pod centos2

cat <<EOF | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "fqdn"
spec:
  endpointSelector:
    matchLabels:
      org: empire
      class: mediabot
  egress:
  - toFQDNs:
    - matchName: "api.twitter.com"  
  - toEndpoints:
    - matchLabels:
        "k8s:io.kubernetes.pod.namespace": kube-system
        "k8s:k8s-app": kube-dns
    toPorts:
    - ports:
      - port: "53"
        protocol: ANY
      rules:
        dns:
        - matchPattern: "*"
EOF