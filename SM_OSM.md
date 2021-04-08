## Addon
https://github.com/openservicemesh/osm


az aks enable-addons --addons "open-service-mesh" --name $KUBE_NAME --resource-group $KUBE_GROUP 

kubectl get configmap -n kube-system osm-config -o JSON

kubectl edit ConfigMap osm-config -n kube-system

move to permissive mode


kubectl patch ConfigMap osm-config -n kube-system -p '{"data":"permissive_traffic_policy_mode":"false"}}' --type=merge  

kubectl patch ConfigMap osm-config -n osm-system -p '{"data":{"use_https_ingress":"true"}}' --type=merge


kubectl patch ConfigMap osm-config -n kube-system -p '{"data":"use_https_ingress":"true"}}' --type=merge  


osm namespace add bookbuyer --mesh-name osm --enable-sidecar-injection 
osm namespace add bookstore --mesh-name osm --enable-sidecar-injection 

## OSM Binary

https://blog.nillsf.com/index.php/2020/08/11/taking-the-open-service-mesh-for-a-test-drive/

OSM_VERSION=v0.8.0

curl -sL "https://github.com/openservicemesh/osm/releases/download/$OSM_VERSION/osm-$OSM_VERSION-linux-amd64.tar.gz" | tar -vxzf -

wget https://github.com/openservicemesh/osm/releases/download/v0.4.0/osm-v0.4.0-darwin-amd64.tar.gz
tar -xvzf osm-v0.3.0-darwin-amd64.tar.gz

cp darwin-amd64/osm ~/lib/osm 
alias osm='/Users/dennis/lib/osm/osm' 


osm install


git clone https://github.com/openservicemesh/osm.git
cd osm

## OSM Demo

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

## OSM Demo

https://github.com/openservicemesh/osm/blob/main/demo/README.md

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

# TrafficTarget is deny-by-default policy: if traffic from source to destination is not
# explicitly declared in this policy - it will be blocked.
# Should we ever want to allow traffic from bookthief to bookstore the block below needs
# uncommented.

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

## Tracing


osm mesh upgrade --enable-tracing --tracing-address  otel-collector.default.svc.cluster.local --tracing-port 9411 --tracing-endpoint /api/v2/spans
