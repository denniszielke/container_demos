## Addon
https://github.com/openservicemesh/osm
https://github.com/microsoft/Docker-Provider/blob/ci_dev/Documentation/OSMPrivatePreview/ReadMe.md

```
az aks enable-addons --addons "open-service-mesh" --name $KUBE_NAME --resource-group $KUBE_GROUP 

kubectl get configmap -n kube-system osm-config -o JSON

kubectl edit ConfigMap osm-config -n kube-system

move to permissive mode


kubectl patch ConfigMap osm-config -n kube-system -p '{"data":"permissive_traffic_policy_mode":"false"}}' --type=merge  

kubectl patch ConfigMap osm-config -n osm-system -p '{"data":{"use_https_ingress":"true"}}' --type=merge


kubectl patch ConfigMap osm-config -n kube-system -p '{"data":"use_https_ingress":"true"}}' --type=merge  


kubectl get configmap -n kube-system osm-config -o json | jq '.data.prometheus_scraping'
kubectl patch ConfigMap -n kube-system osm-config --type merge --patch '{"data":{"prometheus_scraping":"true"}}'

kubectl patch configmap osm-config -n kube-system -p '{"data":{"tracing_enable":"true", "tracing_address":"otel-collector.default.svc.cluster.local", "tracing_port":"9411", "tracing_endpoint":"/api/v2/spans"}}' --type=merge

otel-collector.default.svc.cluster.local --tracing-port 9411 --tracing-endpoint /api/v2/spans


osm namespace add bookbuyer --mesh-name osm --enable-sidecar-injection 
osm namespace add bookstore --mesh-name osm --enable-sidecar-injection 
```

## OSM Binary

https://blog.nillsf.com/index.php/2020/08/11/taking-the-open-service-mesh-for-a-test-drive/

```
OSM_VERSION=v0.8.0

curl -sL "https://github.com/openservicemesh/osm/releases/download/$OSM_VERSION/osm-$OSM_VERSION-linux-amd64.tar.gz" | tar -vxzf -

wget https://github.com/openservicemesh/osm/releases/download/v0.4.0/osm-v0.4.0-darwin-amd64.tar.gz
tar -xvzf osm-v0.3.0-darwin-amd64.tar.gz

cp darwin-amd64/osm ~/lib/osm 
alias osm='/Users/dennis/lib/osm/osm' 


osm install


git clone https://github.com/openservicemesh/osm.git
cd osm
```

## OSM Custom Demo

```
kubectl create ns debugdemo

kubectl apply -f tracing -n debugdemo

osm namespace add debugdemo
osm metrics enable --namespace debugdemo

cat <<EOF | kubectl apply -f -
kind: ConfigMap
apiVersion: v1
data:
  schema-version:
    #string.used by agent to parse OSM config. supported versions are {v1}. Configs with other schema versions will be rejected by the agent.
    v1
  config-version:
    #string.used by OSM addon team to keep track of this config file's version in their source control/repository (max allowed 10 chars, other chars will be truncated)
    ver1
  osm-metric-collection-configuration: |-
    # OSM metric collection settings
    [osm_metric_collection_configuration.settings]
        # Namespaces to monitor
        # monitor_namespaces = ["debugdemo"]
metadata:
  name: container-azm-ms-osmconfig
  namespace: kube-system
EOF

kubectl rollout restart deploy -n debugdemo

```

## OSM Demo

```
kubectl create ns bookstore
kubectl create ns bookthief 
kubectl create ns bookwarehouse 
kubectl create ns bookbuyer

osm namespace add bookstore
osm namespace add bookthief
osm namespace add bookwarehouse
osm namespace add bookbuyer


kubectl apply -f osm/osm-full.yaml

kubectl rollout status deployment --timeout 300s -n bookstore bookstore-v1
kubectl rollout status deployment --timeout 300s -n bookstore bookstore-v2
kubectl rollout status deployment --timeout 300s -n bookthief bookthief
kubectl rollout status deployment --timeout 300s -n bookwarehouse bookwarehouse
kubectl rollout status deployment --timeout 300s -n bookbuyer bookbuyer

kubectl port-forward -n bookthief deploy/bookthief 8080:80

kubectl port-forward -n bookbuyer deploy/bookbuyer 8081:80

kubectl port-forward -n bookstore deploy/bookstore-v1 8085:80

kubectl port-forward -n bookbuyer deploy/bookbuyer 8080:14001

```

## OSM Demo

https://github.com/openservicemesh/osm/blob/main/demo/README.md

```
cat <<EOF | kubectl apply -f -
apiVersion: specs.smi-spec.io/v1alpha3 
kind: HTTPRouteGroup 
metadata: 
  name: bookstore-service-routes 
  namespace: bookstore 
spec: 
  matches: 
  - name: books-bought 
    pathRegex: /books-bought 
    methods: 
    - GET 
    headers: 
    - "user-agent": ".*-http-client/*.*" 
    - "client-app": "bookbuyer" 
  - name: buy-a-book 
    pathRegex: ".*a-book.*new" 
    methods: 
    - GET 
  - name: update-books-bought 
    pathRegex: /update-books-bought 
    methods: 
    - POST 
EOF


cat <<EOF | kubectl apply -f -
kind: TrafficTarget
apiVersion: access.smi-spec.io/v1alpha2
metadata:
  name: bookbuyer-access-bookstore
  namespace: "bookstore"
spec:
  destination:
    kind: ServiceAccount
    name: bookstore
    namespace: "bookstore"
  rules:
  - kind: HTTPRouteGroup
    name: bookstore-service-routes
    matches:
    - buy-a-book
    - books-bought
  sources:
  - kind: ServiceAccount
    name: bookbuyer
    namespace: "bookbuyer"
EOF

cat <<EOF | kubectl apply -f -
kind: TrafficTarget
apiVersion: access.smi-spec.io/v1alpha2
metadata:
  name: bookbuyer-access-bookstore-v2
  namespace: bookstore
spec:
  destination:
    kind: ServiceAccount
    name: bookstore
    namespace: bookstore
  rules:
  - kind: HTTPRouteGroup
    name: bookstore-service-routes
    matches:
    - buy-a-book
    - books-bought
  sources:
  - kind: ServiceAccount
    name: bookbuyer
    namespace: bookbuyer
EOF

cat <<EOF | kubectl apply -f -
apiVersion: split.smi-spec.io/v1alpha2 
kind: TrafficSplit 
metadata: 
  name: bookstore-split 
  namespace: bookstore 
spec: 
  service: bookstore.bookstore 
  backends: 
  - service: bookstore-v1 
    weight: 25 
  - service: bookstore-v2 
    weight: 75 
EOF
```

# TrafficTarget is deny-by-default policy: if traffic from source to destination is not
# explicitly declared in this policy - it will be blocked.
# Should we ever want to allow traffic from bookthief to bookstore the block below needs
# uncommented.

```
cat <<EOF | kubectl apply -f -
kind: TrafficTarget
apiVersion: access.smi-spec.io/v1alpha2
metadata:
  name: bookbuyer-access-bookstore
  namespace: "bookstore"
spec:
  destination:
    kind: ServiceAccount
    name: bookstore
    namespace: "bookstore"
  rules:
  - kind: HTTPRouteGroup
    name: bookstore-service-routes
    matches:
    - buy-a-book
    - books-bought
  sources:
  - kind: ServiceAccount
    name: bookbuyer
    namespace: "bookbuyer"
  - kind: ServiceAccount
    name: bookthief
    namespace: "bookthief"
EOF


kubectl edit TrafficTarget bookbuyer-access-bookstore-v1 -n bookstore

kubectl edit trafficsplits bookstore-split -n bookstore
```

## Tracing

```
osm mesh upgrade --enable-tracing --tracing-address  otel-collector.default.svc.cluster.local --tracing-port 9411 --tracing-endpoint /api/v2/spans
```