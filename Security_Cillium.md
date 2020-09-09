# Cillium

## Install
https://docs.cilium.io/en/latest/gettingstarted/k8s-install-aks/

```
kubectl apply -f cilium/cilium-cm.yaml

curl -sL https://github.com/cilium/cilium/archive/master.tar.gz | tar xz

cd cilium-master/install/kubernetes


helm template cilium \
  --namespace cilium \
  --set global.cni.chainingMode=generic-veth \
  --set global.cni.customConf=true \
  --set global.nodeinit.enabled=true \
  --set global.cni.configMap=cni-configuration \
  --set global.tunnel=disabled \
  --set global.masquerade=false \
  > ../../../container_demos/cilium/cilium-full.yaml

helm template cilium \
  --namespace cilium \
  --set global.cni.chainingMode=generic-veth \
  --set global.cni.customConf=true \
  --set global.nodeinit.enabled=true \
  --set nodeinit.azure=true \
  --set global.cni.configMap=cni-configuration \
  --set global.tunnel=disabled \
  --set global.masquerade=false \
  > ../../../container_demos/cilium/cilium-full.yaml

helm template cilium cilium/cilium --version 1.8.0 \
  --namespace cilium \
  --set global.cni.chainingMode=generic-veth \
  --set global.cni.customConf=true \
  --set global.nodeinit.enabled=true \
  --set nodeinit.azure=true \
  --set global.cni.configMap=cni-configuration \
  --set global.tunnel=disabled \
  --set global.masquerade=false  \
  > cilium/cilium-full.yaml

cd ../../../

kubectl apply -f cilium/cilium-full.yaml

kubectl -n kube-system get pods --watch
kubectl -n cilium get pods --watch
```

deploy connectivity set
```
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/HEAD/examples/kubernetes/connectivity-check/connectivity-check.yaml



kubectl logs -l name=echo
kubectl logs -l name=probe
```

## Configure Hubble
https://github.com/cilium/hubble

```
git clone https://github.com/cilium/hubble.git
git clone https://github.com/cilium/hubble.git --branch v0.5

cd hubble/install/kubernetes

helm template hubble \
    --namespace kube-system \
    --set metrics.enabled="{dns:query;ignoreAAAA;destinationContext=pod-short,drop:sourceContext=pod;destinationContext=pod,tcp,flow,port-distribution,icmp,http}" \
    --set ui.enabled=true \
  > ../../../container_demos/cilium/hubble.yaml

kubectl apply -f cilium/hubble.yaml


kubectl create -f https://raw.githubusercontent.com/cilium/cilium/master/install/kubernetes/quick-install.yaml
kubectl create -f https://raw.githubusercontent.com/cilium/hubble/master/tutorials/deploy-hubble-servicemap/hubble-all-minikube.yaml


export NAMESPACE=kube-system
export POD_NAME=$(kubectl get pods --namespace $NAMESPACE -l "k8s-app=hubble-ui" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace $NAMESPACE port-forward $POD_NAME 12000

```

## Configure calculator with cillium


cat <<EOF | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "calculator-to-appinsights-allowed-cnp"
  namespace: calculator
spec:
  endpointSelector:
    matchLabels:
      "app.kubernetes.io/name": multicalculatorv3
  egress:
  - toFQDNs:
    - matchPattern: "*.visualstudio.com"
EOF

cat <<EOF | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "calculator-to-app-allowed-cnp"
  namespace: calculator
spec:
  endpointSelector:
    matchLabels:
      role: frontend
      k8s:io.kubernetes.pod.namespace: redis
  egress:
  - toFQDNs:
    - matchPattern: "redis-master.redis.svc.cluster.local"
  - toEndpoints:
    - matchLabels:
        "k8s:io.kubernetes.pod.namespace": redis
        app: redis
    toPorts:
    - ports:
      - port: "6379"
        protocol: TCP
  - toEndpoints:
    - matchLabels:
        role: backend
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
  - toEndpoints:
    - matchLabels:
        "k8s:io.kubernetes.pod.namespace": kube-system
        "k8s:k8s-app": kube-dns
    toPorts:
    - ports:
      - port: "53"
        protocol: UDP
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: centos
  namespace: calculator
  labels:
    role: frontend
spec:
  containers:
  - name: centoss
    image: centos
    ports:
    - containerPort: 80
    command:
    - sleep
    - "3600"
EOF



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