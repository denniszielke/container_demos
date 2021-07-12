KUBE_NAME=$1
KUBE_GROUP=$2
USE_ADDON=$3

SUBSCRIPTION_ID=$(az account show --query id -o tsv) #subscriptionid
LOCATION=$(az group show -n $KUBE_GROUP --query location -o tsv)
NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv)
AKS_SUBNET_ID=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query "agentPoolProfiles[0].vnetSubnetId" -o tsv)
AKS_SUBNET_NAME="aks-5-subnet"
APPGW_SUBNET_ID=$(echo ${AKS_SUBNET_ID%$AKS_SUBNET_NAME*}gw-1-subnet)

echo "creating appgw in subnet $APPGW_SUBNET_ID ..."

APPGW_PUBLIC_IP=$(az network public-ip show -g $KUBE_GROUP -n appgw-pip --query ipAddress -o tsv)
if [ "$APPGW_PUBLIC_IP" == "" ]; then
echo "creating public ip appgw-pip ..."
az network public-ip create --resource-group $KUBE_GROUP --name appgw-pip --allocation-method Static --sku Standard --dns-name $KUBE_NAME
APPGW_PUBLIC_IP=$(az network public-ip show -g $KUBE_GROUP -n appgw-pip --query ipAddress -o tsv)
fi

APPGW_RESOURCE_ID=""#$(az network application-gateway list --resource-group=$KUBE_GROUP -o json | jq -r ".[0].id")

#if [ "$APPGW_RESOURCE_ID" == "" ]; then
echo "creating application gateway $KUBE_NAME-appgw..."
az network application-gateway create --name $KUBE_NAME-appgw --resource-group $KUBE_GROUP --location $LOCATION --http2 Enabled --min-capacity 0 --max-capacity 10 --sku WAF_v2  --subnet $APPGW_SUBNET_ID --http-settings-cookie-based-affinity Disabled --frontend-port 80 --http-settings-port 80 --http-settings-protocol Http --public-ip-address appgw-pip --private-ip-address "10.0.2.100"
APPGW_NAME=$(az network application-gateway list --resource-group=$KUBE_GROUP -o json | jq -r ".[0].name")
APPGW_RESOURCE_ID=$(az network application-gateway list --resource-group=$KUBE_GROUP -o json | jq -r ".[0].id")
APPGW_SUBNET_ID=$(az network application-gateway list --resource-group=$KUBE_GROUP -o json | jq -r ".[0].gatewayIpConfigurations[0].subnet.id")
#fi

APPGW_ADDON_ENABLED=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query addonProfiles.ingressApplicationGateway.enabled --output tsv)
if [ "$APPGW_ADDON_ENABLED" == "" ]; then
echo "enabling ingress-appgw addon for $APPGW_RESOURCE_ID"
az aks enable-addons --resource-group $KUBE_GROUP --name $KUBE_NAME -a ingress-appgw --appgw-id $APPGW_RESOURCE_ID
fi
exit
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

kubectl apply -f - <<EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: appgw-dummy-ingress
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
spec:
  rules:
  - host: $APPGW_DNS
    http:
      paths:
      - backend:
          serviceName: dummy-logger-cluster
          servicePort: 80
EOF