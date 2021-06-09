# Istio


## Install istioctl
```
https://istio.io/latest/docs/setup/getting-started/#download

curl -L https://istio.io/downloadIstio | sh -

export PATH=$PATH:$HOME/lib/istio-1.7.3


istioctl install --set profile=demo
istioctl install --set profile=default

istioctl profile dump default

az aks nodepool add -g $KUBE_GROUP --cluster-name $KUBE_NAME -n istio2 -c 4 --node-vm-size Standard_DS3_v2 --mode system

istioctl profile dump --config-path components.ingressGateways
istioctl profile dump --config-path values.gateways.istio-ingressgateway

istioctl install --set components.telemetry.enabled=true
--set addonComponents.grafana.enabled=true


istioctl analyze

kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.7/samples/addons/kiali.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.7/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.7/samples/addons/grafana.yaml

istioctl x uninstall --purge
kubectl delete namespace istio-system
```
## Example
https://istio.io/latest/docs/examples/bookinfo/

```
kubectl label namespace default istio-injection=enabled
kubectl label namespace default istio-injection=disabled


kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.7/samples/bookinfo/platform/kube/bookinfo.yaml


kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.7/samples/bookinfo/networking/bookinfo-gateway.yaml

kubectl get svc istio-ingressgateway -n istio-system
export INGRESS_HOST=$(kubectl get po -l istio=ingressgateway -n istio-system -o jsonpath='{.items[0].status.hostIP}')
echo $INGRESS_HOST
```

## ingress

https://istio.io/latest/docs/tasks/traffic-management/ingress/ingress-control/
```
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.7/samples/httpbin/httpbin.yaml


kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: httpbin-gateway
spec:
  selector:
    istio: ingressgateway # use Istio default gateway implementation
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "httpbin.example.com"
EOF

kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin
spec:
  hosts:
  - "httpbin.example.com"
  gateways:
  - httpbin-gateway
  http:
  - match:
    - uri:
        prefix: /status
    - uri:
        prefix: /delay
    route:
    - destination:
        port:
          number: 8000
        host: httpbin
EOF
```

## GRPC 

https://github.com/mhamrah/grpc-example
https://github.com/grpc-ecosystem/grpc-gateway
```
kubectl apply -f https://raw.githubusercontent.com/mhamrah/grpc-example/master/k8s/setup/namespace.yaml

kubectl label namespace todos istio-injection=enabled

kubectl apply -f https://raw.githubusercontent.com/mhamrah/grpc-example/master/k8s/todos-client.yaml
kubectl apply -f https://raw.githubusercontent.com/mhamrah/grpc-example/master/k8s/todos-server.yaml
kubectl apply -f https://raw.githubusercontent.com/mhamrah/grpc-example/master/k8s/autoscale.yaml

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
   name: todos-client
   namespace: todos
   labels:
      app: todos
      tier: client
spec:
  replicas: 1
  selector:
    matchLabels:
      app: todos
      tier: client
  template:
    metadata:
      labels:
        app: todos
        tier: client
    spec:
      containers:
      - name: todos-client
        image: denniszielke/todos-client
        env:
          - name: BACKEND
            value: "todos-server:50052"
EOF

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
   name: todos-server
   namespace: todos
   labels:
      app: todos
      tier: server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: todos
      tier: server
  template:
    metadata:
      labels:
        app: todos
        tier: server
    spec:
      containers:
      - name: todos-server
        image: denniszielke/todos-server
        ports:
        - containerPort: 50052
        resources:
          requests:
            cpu: 100m
            memory: 128M
          limits:
            cpu: 200m
            memory:  256M
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: todos-server
  namespace: todos
spec:
  selector:
    app: todos
    tier: server
  ports:
  - name: grpc
    port: 50052
EOF

cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: grpc-gateway
  namespace: todos
spec:
  selector:
    istio: ingressgateway # use istio default controller
  servers:
  - port:
      number: 50052
      name: todos-server
      protocol: GRPC
    hosts:
    - "*"
EOF

cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: grpc-demo
  namespace: todos
spec:
  hosts:
  - "*"
  gateways:
  - grpc-gateway
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: todos-server
        port:
          number: 50052
EOF

cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: todos-server
spec:
  host: todos-server
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
EOF

ISTIO_GW=52.236.17.171

grpcurl -plaintext $ISTIO_GW:50052 describe
grpcurl -plaintext -d '{ "id": "01E4Q00M7YPD06TX3YW8DMFF8B" }' $ISTIO_GW:50052 todos.Todos/GetTodo
curl  -X POST http://$ISTIO_GW:51052/todos -H 'Content-Type: application/json' -d '{ "id":  "01E4Q00M7YPD06TX3YW8DMFF8B" }'
```

# Authorization
```
kubectl create ns foo
kubectl apply -f <(istioctl kube-inject -f https://raw.githubusercontent.com/istio/istio/release-1.7/samples/httpbin/httpbin.yaml) -n foo
kubectl apply -f <(istioctl kube-inject -f https://raw.githubusercontent.com/istio/istio/release-1.7/samples/sleep/sleep.yaml) -n foo

kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- curl http://httpbin.foo:8000/ip -s -o /dev/null -w "%{http_code}\n"

cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
 name: httpbin
 namespace: foo
spec:
 selector:
   matchLabels:
     app: httpbin
     version: v1
 action: ALLOW
 rules:
 - from:
   - source:
       principals: ["cluster.local/ns/default/sa/sleep"]
   - source:
       namespaces: ["dev"]
   to:
   - operation:
       methods: ["GET"]
   when:
   - key: request.auth.claims[iss]
     values: ["https://accounts.google.com"]
EOF

cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
 name: httpbin-deny
 namespace: foo
spec:
 selector:
   matchLabels:
     app: httpbin
     version: v1
 action: DENY
 rules:
 - from:
   - source:
       notNamespaces: ["foo"]
EOF
```
