
# Consul

new ui
https://www.hashicorp.com/blog/service-mesh-visualization-in-hashicorp-consul-1-9

## Install 

brew tap hashicorp/tap

brew install hashicorp/tap/consul

brew upgrade hashicorp/tap/consul

## Helm

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

kubectl port-forward pod/dashboard 9001:9001

kubectl apply -f consul/counting-minimal-svc.yaml

kubectl exec -it counting-minimal-pod /bin/sh

## Consul Helm

helm repo add hashicorp https://helm.releases.hashicorp.com

helm search repo hashicorp/consul
helm repo update
helm search repo hashicorp/consul
kubectl create namespace consul
helm upgrade consul hashicorp/consul --install --set global.name=consul --set connectInject.enabled=true  \
  --set client.enabled=true --set client.grpc=true --namespace consul

helm upgrade consul hashicorp/consul --install -f consul/consul-values.yaml --namespace consul

kubectl get secrets/consul-bootstrap-acl-token --template={{.data.token}} | base64 -D

kubectl port-forward service/consul-server 8500:8500 -n consul


## Consul Helm 1.9

helm repo add hashicorp https://helm.releases.hashicorp.com

helm search repo hashicorp/consul
helm repo update
helm search repo hashicorp/consul
kubectl create namespace consul
helm upgrade consul hashicorp/consul --install --set global.name=consul --set connectInject.enabled=true  \
  --set client.enabled=true --set client.grpc=true --namespace consul

helm upgrade consul hashicorp/consul --install -f consul/consul-values.yaml --set global.image=consul:1.9.0-beta1 --set controller.enabled=true --namespace consul

kubectl get secrets/consul-bootstrap-acl-token --template={{.data.token}} | base64 -D

kubectl port-forward service/consul-server 8500:8500 -n consul

kubectl port-forward pods/ambassador-65586b5bc6-94jn9 8877:8877

http://localhost:8877/ambassador/v0/diag/

## Consul helm TLS

consul tls ca create

consul tls cert create -server

kubectl create secret generic consul-ca-cert --from-file='tls.crt=./consul-agent-ca.pem'

kubectl create secret generic consul-ca-key --from-file='tls.key=./consul-agent-ca-key.pem'

helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm search repo hashicorp/consul
kubectl create namespace consul

helm upgrade consul hashicorp/consul --install -f consul/consul-values.yaml --namespace consul

kubectl get secrets/consul-bootstrap-acl-token --template={{.data.token}} | base64 -D

kubectl port-forward service/consul-ui 8500:443 -n consul

## Consul agent
https://learn.hashicorp.com/tutorials/consul/get-started-agent

consul agent -dev

consul members

consul intentions
https://learn.hashicorp.com/tutorials/consul/kubernetes-custom-resource-definitions

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

## KV

consul kv put redis/config/minconns 1

consul kv put redis/config/maxconns 25

consul kv put -flags=42 redis/config/users/admin abcd1234

consul kv get redis/config/minconns

consul kv get -detailed redis/config/users/admin

consul kv delete -recurse redis

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: consul-example
spec:
  containers:
    - name: example
      image: 'consul:latest'
      env:
        - name: HOST_IP
          valueFrom:
            fieldRef:
              fieldPath: status.hostIP
      command:
        - '/bin/sh'
        - '-ec'
        - |
          export CONSUL_HTTP_ADDR="${HOST_IP}:8500"
          consul kv put hello world
  restartPolicy: Never
EOF

## Metrics

https://learn.hashicorp.com/tutorials/consul/kubernetes-layer7-observability?in=consul/interactive

Grafana dashboard
https://raw.githubusercontent.com/hashicorp/consul-k8s-prometheus-grafana-hashicups-demoapp/master/grafana/hashicups-dashboard.json

kubectl get secret --namespace $LOKI_NS $LOKI_IN-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
kubectl port-forward --namespace $LOKI_NS service/$LOKI_IN-grafana 3000:80

kubectl apply -f https://raw.githubusercontent.com/hashicorp/consul-k8s-prometheus-grafana-hashicups-demoapp/master/app/frontend.yaml
kubectl apply -f https://raw.githubusercontent.com/hashicorp/consul-k8s-prometheus-grafana-hashicups-demoapp/master/app/products-api.yaml
kubectl apply -f https://raw.githubusercontent.com/hashicorp/consul-k8s-prometheus-grafana-hashicups-demoapp/master/app/products-db.yaml
kubectl apply -f https://raw.githubusercontent.com/hashicorp/consul-k8s-prometheus-grafana-hashicups-demoapp/master/app/public-api.yaml

kubectl port-forward deploy/frontend 8080:80

kubectl port-forward deploy/frontend 19000:19000

open http://localhost:19000/config_dump

kubectl port-forward deploy/my-loki-prometheus-server  9090:9090 -n loki

sum by(__name__)({app="products-api"})

kubectl apply -f https://raw.githubusercontent.com/hashicorp/consul-k8s-prometheus-grafana-hashicups-demoapp/master/traffic.yaml



kubectl delete -f https://raw.githubusercontent.com/hashicorp/consul-k8s-prometheus-grafana-hashicups-demoapp/master/app/frontend.yaml
kubectl delete -f https://raw.githubusercontent.com/hashicorp/consul-k8s-prometheus-grafana-hashicups-demoapp/master/app/products-api.yaml
kubectl delete -f https://raw.githubusercontent.com/hashicorp/consul-k8s-prometheus-grafana-hashicups-demoapp/master/app/products-db.yaml
kubectl delete -f https://raw.githubusercontent.com/hashicorp/consul-k8s-prometheus-grafana-hashicups-demoapp/master/app/public-api.yaml

kubectl delete -f https://raw.githubusercontent.com/hashicorp/consul-k8s-prometheus-grafana-hashicups-demoapp/master/traffic.yaml

## demo counting

kubectl apply -f https://raw.githubusercontent.com/hashicorp/demo-consul-101/master/k8s/04-yaml-connect-envoy/counting-service.yaml

kubectl apply -f https://raw.githubusercontent.com/hashicorp/demo-consul-101/master/k8s/04-yaml-connect-envoy/dashboard-service.yaml


kubectl delete -f https://raw.githubusercontent.com/hashicorp/demo-consul-101/master/k8s/04-yaml-connect-envoy/counting-service.yaml

kubectl delete -f https://raw.githubusercontent.com/hashicorp/demo-consul-101/master/k8s/04-yaml-connect-envoy/dashboard-service.yaml


## demo simple client server

kubectl apply -f consul/demo-api.yaml   
kubectl apply -f consul/demo-web.yaml 


kubectl port-forward service/web 9090:9090 --address 0.0.0.0