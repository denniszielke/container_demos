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


## Custom Auth
https://istio.io/latest/blog/2021/better-external-authz/

example auth policy
```
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: ext-authz
  namespace: istio-system
spec:
  # The selector applies to the ingress gateway in the istio-system namespace.
  selector:
    matchLabels:
      app: istio-ingressgateway
  # The action "CUSTOM" delegates the access control to an external authorizer, this is different from
  # the ALLOW/DENY action that enforces the access control right inside the proxy.
  action: CUSTOM
  # The provider specifies the name of the external authorizer defined in the meshconfig, which tells where and how to
  # talk to the external auth service. We will cover this more later.
  provider:
    name: "my-ext-authz-service"
  # The rule specifies that the access control is triggered only if the request path has the prefix "/admin/".
  # This allows you to easily enable or disable the external authorization based on the requests, avoiding the external
  # check request if it is not needed.
  rules:
  - to:
    - operation:
        paths: ["/admin/*"]
EOF
```


```
cat > policy.rego <<EOF
package envoy.authz

import input.attributes.request.http as http_request

default allow = false

token = {"valid": valid, "payload": payload} {
    [_, encoded] := split(http_request.headers.authorization, " ")
    [valid, _, payload] := io.jwt.decode_verify(encoded, {"secret": "secret"})
}

allow {
    is_token_valid
    action_allowed
}

is_token_valid {
  token.valid
  now := time.now_ns() / 1000000000
  token.payload.nbf <= now
  now < token.payload.exp
}

action_allowed {
  startswith(http_request.path, base64url.decode(token.payload.path))
}
EOF

kubectl create ns opasvc

kubectl label ns opademo istio-injection=enabled

kubectl label namespace opasvc istio.io/rev=asm-1-17


kubectl create secret generic opa-policy -n opasvc --from-file policy.rego

kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: opa
  namespace: opasvc
  labels:
    app: opa
spec:
  ports:
  - name: grpc
    port: 9191
    targetPort: 9191
  selector:
    app: opa
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: opa
  namespace: opasvc
  labels:
    app: opa
spec:
  replicas: 1
  selector:
    matchLabels:
      app: opa
  template:
    metadata:
      labels:
        app: opa
    spec:
      containers:
        - name: opa
          image: openpolicyagent/opa:latest-envoy
          securityContext:
            runAsUser: 1111
          volumeMounts:
          - readOnly: true
            mountPath: /policy
            name: opa-policy
          args:
          - "run"
          - "--server"
          - "--addr=localhost:8181"
          - "--diagnostic-addr=0.0.0.0:8282"
          - "--set=plugins.envoy_ext_authz_grpc.addr=:9191"
          - "--set=plugins.envoy_ext_authz_grpc.query=data.envoy.authz.allow"
          - "--set=decision_logs.console=true"
          - "--ignore=.*"
          - "/policy/policy.rego"
          ports:
          - containerPort: 9191
          livenessProbe:
            httpGet:
              path: /health?plugins
              scheme: HTTP
              port: 8282
            initialDelaySeconds: 5
            periodSeconds: 5
          readinessProbe:
            httpGet:
              path: /health?plugins
              scheme: HTTP
              port: 8282
            initialDelaySeconds: 5
            periodSeconds: 5
      volumes:
        - name: proxy-config
          configMap:
            name: proxy-config
        - name: opa-policy
          secret:
            secretName: opa-policy
EOF

kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.17/samples/httpbin/httpbin.yaml -n opasvc

```

define external authorizer

```
kubectl edit configmap istio-asm-1-17 -n aks-istio-system

apiVersion: v1
data:
  mesh: |-
    defaultConfig:
      discoveryAddress: istiod-asm-1-17.aks-istio-system.svc:15012
      gatewayTopology:
        numTrustedProxies: 1
      image:
        imageType: distroless
      tracing:
        zipkin:
          address: zipkin.aks-istio-system:9411
    enablePrometheusMerge: true
    rootNamespace: aks-istio-system
    trustDomain: cluster.local
  meshNetworks: 'networks: {}'
kind: ConfigMap
metadata:
  annotations:
    meta.helm.sh/release-name: azure-service-mesh-istio-discovery
    meta.helm.sh/release-namespace: aks-istio-system
  creationTimestamp: "2023-05-03T14:38:16Z"
  labels:
    app.kubernetes.io/managed-by: Helm
    helm.toolkit.fluxcd.io/name: azure-service-mesh-istio-discovery-helmrelease
    helm.toolkit.fluxcd.io/namespace: 64523969922c4900013c0af0
    install.operator.istio.io/owning-resource: unknown
    istio.io/rev: asm-1-17
    operator.istio.io/component: Pilot
    release: azure-service-mesh-istio-discovery
  name: istio-asm-1-17
  namespace: aks-istio-system
  resourceVersion: "57453"
  uid: 1481ce3d-e8c6-4ff9-90ba-dd2371691ef5

apiVersion: v1
data:
  mesh: |-
    # Add the following contents:
    extensionProviders:
    - name: "opa.opasvc"
      envoyExtAuthzGrpc:
        service: "opa.opasvc.svc.cluster.local"
        port: "9191"

kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: httpbin-opa
  namespace: opasvc
spec:
  selector:
    matchLabels:
      app: httpbin
  action: CUSTOM
  provider:
    name: "opa.opasvc"
  rules:
  - to:
    - operation:
        notPaths: ["/ip"]
EOF

```


test the policy

```
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.17/samples/sleep/sleep.yaml

export SLEEP_POD=$(kubectl get pod -l app=sleep -o jsonpath={.items..metadata.name})

export TOKEN_PATH_HEADERS="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJwYXRoIjoiTDJobFlXUmxjbk09IiwibmJmIjoxNTAwMDAwMDAwLCJleHAiOjE5MDAwMDAwMDB9.9yl8LcZdq-5UpNLm0Hn0nnoBHXXAnK4e8RSl9vn6l98

kubectl exec ${SLEEP_POD} -c sleep  -- curl http://httpbin-with-opa:8000/headers -s -o /dev/null -w "%{http_code}\n"

```