# Ambassador
https://www.getambassador.io/user-guide/helm/

```

helm repo add datawire https://www.getambassador.io


IP=
IP_NAME=ambassador-ingress-pip
AMB_NS=ambassador
AMB_IN=ambassador-ingress


DNS=$(az network public-ip show --resource-group $NODE_GROUP --name $IP_NAME --query dnsSettings.fqdn --output tsv)
IP=$(az network public-ip show --resource-group $NODE_GROUP --name $IP_NAME --query ipAddress --output tsv)

helm upgrade --install $AMB_IN datawire/ambassador --namespace $AMB_NS
export SERVICE_IP=$(kubectl get svc --namespace default ambassador -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

helm upgrade --install $AMB_IN stable/ambassador --set service.loadBalancerIP=$IP  --set service.externalTrafficPolicy=Local --set crds.create=false --namespace $AMB_NS

helm upgrade --install $AMB_IN stable/ambassador --set service.externalTrafficPolicy=Local --set crds.create=false --namespace $AMB_NS

helm delete $AMB_IN --purge

```

admin
```

export POD_NAME=$(kubectl get pods --namespace $AMB_NS -l "app.kubernetes.io/name=ambassador,app.kubernetes.io/instance=$AMB_IN" -o jsonpath="{.items[0].metadata.name}")

kubectl set env deploy -n kong konga NODE_TLS_REJECT_UNAUTHORIZED=0

kubectl port-forward $POD_NAME --namespace $AMB_NS 8080:8877

http://localhost:8080/ambassador/v0/diag/

kubectl apply -f https://getambassador.io/yaml/tour/tour.yaml

```


```

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: ambassador
spec:
  type: LoadBalancer
  externalTrafficPolicy: Local
  ports:
   - port: 80
  selector:
    service: ambassador
EOF
```

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: httpbin
  annotations:
    getambassador.io/config: |
      ---
      apiVersion: ambassador/v1
      kind:  Mapping
      name:  httpbin_mapping
      prefix: /httpbin/
      service: httpbin.org:80
      host_rewrite: httpbin.org
spec:
  ports:
  - name: httpbin
    port: 80
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: dummy-logger
  annotations:
    getambassador.io/config: |
      ---
      apiVersion: ambassador/v1
      kind: Mapping
      name: dummylogger_mapping
      prefix: /dummy-logger/
      service: dummy-logger
spec:
  ports:
    - port: 80
      targetPort: 80
      name: http
  selector:
    app: dummy-logger
  type: ClusterIP
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  annotations:
    getambassador.io/config: |
      ---
      apiVersion: ambassador/v0
      kind:  Mapping
      name:  httpbin_mapping
      prefix: /httpbin/
      service: httpbin.org:80
      host_rewrite: httpbin.org
  name: httpbin
spec:
  ports:
    - name: httpbin
      port: 80
EOF
```

SERVICE_IP=20.40.165.62

export SERVICE_IP=$(kubectl get svc --namespace default ambassador -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

curl $SERVICE_IP/httpbin/ip


## Oathkeeper
oathkeeper 
alias oathkeeper='/Users/dennis/lib/oathkeeper/oathkeeper'

openssl rand -hex 16
e1ad13cecb1c9b5f436b09264efdb82e3950f4e4e7429e3a11d5996fb4ed7dab
CREDENTIALS_ISSUER_ID_TOKEN_HS256_SECRET=101bdaa8ceae00490b86330a2498103d

kubectl create secret generic ory-oathkeeper --from-literal=CREDENTIALS_ISSUER_ID_TOKEN_HS256_SECRET=101bdaa8ceae00490b86330a2498103d

kubectl apply -f https://raw.githubusercontent.com/ory/k8s/master/yaml/oathkeeper/simple/oathkeeper-api.yaml

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: ory-oathkeeper
  annotations:
    getambassador.io/config: |
      ---
      apiVersion: ambassador/v1
      kind: Mapping
      name: ory-oathkeeper_mapping
      prefix: /ory-oathkeeper/
      service: ory-oathkeeper
spec:
  ports:
    - name: http-ory-oathkeeper
      port: 80
      targetPort: http-api
  selector:
    app: ory-oathkeeper
  type: ClusterIP
EOF

curl http://$SERVICE_IP/httpbin/health/alive

curl http://$SERVICE_IP/ory-oathkeeper/health/alive

curl http://$SERVICE_IP/dummy-logger/ping

oathkeeper rules --endpoint  http://$SERVICE_IP/ory-oathkeeper list

cat <<EOT > access-rule-oathkeeper.json
[{
  "id": "oathkeeper-access-rule",
  "match": {
    "url": "http://$SERVICE_IP/ory-oathkeeper/<.*>",
    "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD"]
  },
  "authenticators": [{ "handler": "anonymous" }],
  "authorizer": { "handler": "allow" },
  "credentials_issuer": { "handler": "noop" }
}]
EOT


## Quota

cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: Service
metadata:
  name: quote
  namespace: ambassador
spec:
  ports:
  - name: http
    port: 80
    targetPort: 8080
  selector:
    app: quote
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: quote
  namespace: ambassador
spec:
  replicas: 1
  selector:
    matchLabels:
      app: quote
  strategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: quote
    spec:
      containers:
      - name: backend
        image: docker.io/datawire/quote:0.4.1
        ports:
        - name: http
          containerPort: 8080
EOF

cat <<EOF | kubectl apply -f -
---
apiVersion: getambassador.io/v2
kind: Mapping
metadata:
  name: quote-backend
  namespace: ambassador
spec:
  prefix: /backend/
  service: quote
EOF


curl -Lk https://${AMBASSADOR_LB_ENDPOINT}/backend/
{
 "server": "idle-cranberry-8tbb6iks",
 "quote": "Non-locality is the driver of truth. By summoning, we vibrate.",
 "time": "2019-12-11T20:10:16.525471212Z"
}