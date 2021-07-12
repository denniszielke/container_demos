KUBE_NAME=$1
KUBE_GROUP=$2
USE_ADDON=$3

SUBSCRIPTION_ID=$(az account show --query id -o tsv) #subscriptionid
LOCATION=$(az group show -n $KUBE_GROUP --query location -o tsv)
NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv)
AKS_SUBNET_ID=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query "agentPoolProfiles[0].vnetSubnetId" -o tsv)
AKS_SUBNET_NAME="aks-5-subnet"

echo "creating appgw in subnet $APPGW_SUBNET_ID ..."

APPGW_PUBLIC_IP=$(az network public-ip show -g $KUBE_GROUP -n appgw-pip --query ipAddress -o tsv)
if [ "$APPGW_PUBLIC_IP" == "" ]; then
echo "creating public ip appgw-pip ..."
az network public-ip create --resource-group $KUBE_GROUP --name appgw-pip --allocation-method Static --sku Standard --dns-name $KUBE_NAME
APPGW_PUBLIC_IP=$(az network public-ip show -g $KUBE_GROUP -n appgw-pip --query ipAddress -o tsv)
fi

APPGW_RESOURCE_ID=$(az network application-gateway list --resource-group=$KUBE_GROUP -o json | jq -r ".[0].id")

if [ "$APPGW_RESOURCE_ID" == "" ]; then
echo "creating application gateway $KUBE_NAME-appgw..."
az network application-gateway create --name $KUBE_NAME-appgw --resource-group $KUBE_GROUP --location $LOCATION --http2 Enabled --min-capacity 0 --max-capacity 10 --sku WAF_v2  --subnet $APPGW_SUBNET_ID --http-settings-cookie-based-affinity Disabled --frontend-port 80 --http-settings-port 80 --http-settings-protocol Http --public-ip-address appgw-pip --private-ip-address "10.0.1.100"
APPGW_NAME=$(az network application-gateway list --resource-group=$KUBE_GROUP -o json | jq -r ".[0].name")
APPGW_RESOURCE_ID=$(az network application-gateway list --resource-group=$KUBE_GROUP -o json | jq -r ".[0].id")
APPGW_SUBNET_ID=$(az network application-gateway list --resource-group=$KUBE_GROUP -o json | jq -r ".[0].gatewayIpConfigurations[0].subnet.id")
fi

APPGW_ADDON_ENABLED=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query addonProfiles.ingressApplicationGateway.enabled --output tsv)
if [ "$APPGW_ADDON_ENABLED" == "" ]; then
echo "enabling ingress-appgw addon for $APPGW_RESOURCE_ID"
az aks enable-addons --resource-group $KUBE_GROUP --name $KUBE_NAME -a ingress-appgw --appgw-id $APPGW_RESOURCE_ID

#az aks enable-addons --resource-group dzlima8 --name dzlima8 --addons azure-defender --workspace-resource-id /subscriptions/5abd8123-18f8-427f-a4ae-30bfb82617e5/resourcegroups/dzlima8/providers/microsoft.operationalinsights/workspaces/dzlima8
fi

APPGW_DNS=$(az network public-ip show --resource-group $KUBE_GROUP --name appgw-pip --query dnsSettings.fqdn --output tsv)

kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.13/deploy/manifests/00-crds.yaml --validate=false

kubectl create namespace cert-manager
kubectl label namespace cert-manager cert-manager.io/disable-validation=true
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade --install cert-manager \
  --namespace cert-manager \
  --version v0.13.0 \
  jetstack/cert-manager --wait

echo 'creating ingress objects'

kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/depl-logger.yaml --wait true
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/svc-cluster-logger.yaml --wait true

cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencryptappgw
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: dummy1@email.com
    privateKeySecretRef:
      name: letsencrypt
    solvers:
    - http01:
        ingress:
          class: azure/application-gateway
EOF


kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/depl-logger.yaml
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/svc-cluster-logger.yaml

kubectl apply -f - <<EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: appgw-dummy-ingress
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
    certmanager.k8s.io/cluster-issuer: letsencryptappgw
    cert-manager.io/acme-challenge-type: http01
spec:
  tls:
  - hosts:
    - $APPGW_DNS
    secretName: dummy-secret-name
  rules:
  - host: $APPGW_DNS
    http:
      paths:
      - backend:
          serviceName: dummy-logger-cluster
          servicePort: 80
EOF


kubectl create ns monitoring

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts


helm repo update

helm upgrade prometheus --install prometheus-community/prometheus -n monitoring

helm upgrade osm-grafana --install grafana/grafana -n monitoring
helm install osm-grafana grafana/grafana


kubectl get secret --namespace monitoring osm-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo


GRAF_POD_NAME=$(kubectl get pods -n monitoring -l "app.kubernetes.io/name=grafana" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward -n monitoring $GRAF_POD_NAME 3000


kubectl patch ConfigMap -n kube-system osm-config --type merge --patch '{"data":{"prometheus_scraping":"true"}}'


kubectl get configmap prometheus-server -n monitoring -o yaml > cm-stable-prometheus-server.yml
cp cm-stable-prometheus-server.yml cm-stable-prometheus-server.yml.copy

code cm-stable-prometheus-server.yml

kubectl apply -f cm-stable-prometheus-server.yml -n monitoring

PROM_POD_NAME=$(kubectl get pods -l "app=prometheus,component=server" -o jsonpath="{.items[0].metadata.name}" -n monitoring)
kubectl --namespace monitoring port-forward $PROM_POD_NAME 9090 

http://prometheus-server.monitoring.svc.cluster.local:9090

osm metrics enable --namespace "bookbuyer, bookstore, bookthief, bookwarehouse"


kubectl port-forward -n bookbuyer deploy/bookbuyer 8081:14001

kubectl port-forward -n bookthief deploy/bookthief -n bookthief 8080:14001


kubectl patch ConfigMap -n kube-system osm-config --type merge --patch '{"data":{"permissive_traffic_policy_mode":"true"}}'

kubectl patch ConfigMap -n kube-system osm-config --type merge --patch '{"data":{"permissive_traffic_policy_mode":"false"}}'

kubectl get secret --namespace default osm-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo


kubectl apply -f - <<EOF
---
apiVersion: access.smi-spec.io/v1alpha3
kind: TrafficTarget
metadata:
  name: bookbuyer-access-bookstore
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
---
apiVersion: specs.smi-spec.io/v1alpha4
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
---
kind: TrafficTarget
apiVersion: access.smi-spec.io/v1alpha3
metadata:
  name: bookstore-access-bookwarehouse
  namespace: bookwarehouse
spec:
  destination:
    kind: ServiceAccount
    name: bookwarehouse
    namespace: bookwarehouse
  rules:
  - kind: HTTPRouteGroup
    name: bookwarehouse-service-routes
    matches:
    - restock-books
  sources:
  - kind: ServiceAccount
    name: bookstore
    namespace: bookstore
  - kind: ServiceAccount
    name: bookstore-v2
    namespace: bookstore
---
apiVersion: specs.smi-spec.io/v1alpha4
kind: HTTPRouteGroup
metadata:
  name: bookwarehouse-service-routes
  namespace: bookwarehouse
spec:
  matches:
    - name: restock-books
      methods:
      - POST
      headers:
      - host: bookwarehouse.bookwarehouse
EOF

kubectl patch ConfigMap -n kube-system osm-config --type merge --patch '{"data":{"permissive_traffic_policy_mode":"true"}}'


kubectl delete traffictarget.access.smi-spec.io/bookbuyer-access-bookstore  -n bookstore
kubectl delete httproutegroup.specs.smi-spec.io/bookstore-service-routes -n bookstore
kubectl delete traffictarget.access.smi-spec.io/bookstore-access-bookwarehouse -n bookwarehouse
kubectl delete httproutegroup.specs.smi-spec.io/bookwarehouse-service-routes -n bookwarehouse

kubectl apply -f - <<EOF
---
apiVersion: v1
kind: Service
metadata:
  name: bookstore-v2
  namespace: bookstore
  labels:
    app: bookstore-v2
spec:
  ports:
  - port: 14001
    name: bookstore-port
  selector:
    app: bookstore-v2
---
# Deploy bookstore-v2 Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bookstore-v2
  namespace: bookstore
---
# Deploy bookstore-v2 Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bookstore-v2
  namespace: bookstore
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bookstore-v2
  template:
    metadata:
      labels:
        app: bookstore-v2
    spec:
      serviceAccountName: bookstore-v2
      containers:
        - name: bookstore
          image: openservicemesh/bookstore:v0.8.0
          imagePullPolicy: Always
          ports:
            - containerPort: 14001
              name: web
          command: ["/bookstore"]
          args: ["--path", "./", "--port", "14001"]
          env:
            - name: BOOKWAREHOUSE_NAMESPACE
              value: bookwarehouse
            - name: IDENTITY
              value: bookstore-v2
---
kind: TrafficTarget
apiVersion: access.smi-spec.io/v1alpha3
metadata:
  name: bookbuyer-access-bookstore-v2
  namespace: bookstore
spec:
  destination:
    kind: ServiceAccount
    name: bookstore-v2
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

kubectl delete service/bookstore-v2 -n bookstore
kubectl delete serviceaccount/bookstore-v2 -n bookstore
kubectl delete deployment.apps/bookstore-v2 -n bookstore
kubectl delete traffictarget.access.smi-spec.io/bookbuyer-access-bookstore-v2 -n bookstore

kubectl apply -f - <<EOF
apiVersion: split.smi-spec.io/v1alpha2
kind: TrafficSplit
metadata:
  name: bookstore-split
  namespace: bookstore
spec:
  service: bookstore.bookstore
  backends:
  - service: bookstore
    weight: 25
  - service: bookstore-v2
    weight: 75
EOF

kubectl delete trafficsplit.split.smi-spec.io/bookstore-split -n bookstore


curl -H 'Host: bookbuyer.contoso.com' http://51.144.177.28/
