
# Consul

kubectl create namespace consul
helm upgrade consul -f consul-helm/values.yaml --install --namespace consul ./consul-helm \
  --set connectInject.enabled=true --set connectInject.nodeSelector="beta.kubernetes.io/os: linux" \
  --set client.enabled=true --set client.grpc=true --set client.nodeSelector="beta.kubernetes.io/os: linux" \
  --set server.nodeSelector="beta.kubernetes.io/os: linux" \
  --set syncCatalog.enabled=true --set syncCatalog.nodeSelector="beta.kubernetes.io/os: linux"

kubectl get svc --namespace consul --output wide
kubectl get pod --namespace consul --output wide

https://github.com/hashicorp/demo-consul-101/tree/master/k8s

kubectl port-forward -n consul service/consul-consul-server 8500:8500

kubectl apply -f consul/counting-minimal-pod.yaml

kubectl port-forward pod/counting-minimal-pod 9001:9001

kubectl apply -f consul/counting-minimal-svc.yaml

kubectl exec -it counting-minimal-pod /bin/sh

## Consul DNS
https://www.consul.io/docs/platform/k8s/dns.html

10.2.0.250

kubectl edit configmap coredns -n kube-system

consul {
   errors
   cache 30
   forward . 10.2.0.250
}

kubectl get configmap coredns -n kube-system -o yaml

kubectl get pods --show-all | grep dns

## Demo

kubectl apply -f https://raw.githubusercontent.com/hashicorp/demo-consul-101/master/k8s/04-yaml-connect-envoy/counting-service.yaml

kubectl apply -f https://raw.githubusercontent.com/hashicorp/demo-consul-101/master/k8s/04-yaml-connect-envoy/dashboard-service.yaml