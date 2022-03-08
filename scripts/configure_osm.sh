KUBE_NAME=$1
KUBE_GROUP=$2
USE_ADDON=$3

SUBSCRIPTION_ID=$(az account show --query id -o tsv) #subscriptionid
LOCATION=$(az group show -n $KUBE_GROUP --query location -o tsv)
NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv)
AKS_SUBNET_ID=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query "agentPoolProfiles[0].vnetSubnetId" -o tsv)
AKS_SUBNET_NAME="aks-5-subnet"

OSM_ADDON_ENABLED=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME --query "addonProfiles.openServiceMesh.enabled" -o tsv)
if [ "$OSM_ADDON_ENABLED" == "true" ]; then
  echo "osm addon is already active"
else
  echo "enabling osm addon..."
  az aks enable-addons --resource-group="$KUBE_GROUP" --name="$KUBE_NAME" --addons="open-service-mesh"
fi

https://release-v0-11.docs.openservicemesh.io/docs/demos/ingress_k8s_nginx/

echo "cluster is running osm version:"
kubectl get deployment -n kube-system osm-controller -o=jsonpath='{$.spec.template.spec.containers[:1].image}'
echo "cluster is running osm config:"
kubectl get meshconfig osm-mesh-config -n kube-system -o yaml


#kubectl patch meshconfig osm-mesh-config -n kube-system -p '{"spec":{"traffic":{"enablePermissiveTrafficPolicyMode":true}}}' --type=merge

kubectl edit meshconfig osm-mesh-config -n kube-system

kubectl patch meshconfig osm-mesh-config -n kube-system -p '{"spec":{"certificate:":{"ingressGateway": {"secret": {"name": "osm-nginx-client-cert","namespace": "kube-system"},"subjectAltNames": ["nginx-ingress-ingress-nginx-controller.ingress.cluster.local"],"validityDuration": "24h"}}}}'  --type=merge
kubectl get meshconfig osm-mesh-config -n kube-system

certificate:
    ingressGateway:
      secret:
        name: osm-nginx-client-cert
        namespace: kube-system 
      subjectAltNames:
      - nginx-ingress-ingress-nginx.ingress.cluster.local
      validityDuration: 24h


osm namespace add dummy-logger

osm_namespace=kube-system # replace <osm-namespace> with the namespace where OSM is installed
osm_mesh_name=osm # replace <osm-mesh-name> with the mesh name (use `osm mesh list` command)

nginx_ingress_namespace=ingress # replace <nginx-namespace> with the namespace where Nginx is installed
nginx_ingress_service=nginx-ingress-ingress-nginx-controller # replace <nginx-ingress-controller-service> with the name of the nginx ingress controller service
nginx_ingress_host="$(kubectl -n "$nginx_ingress_namespace" get service "$nginx_ingress_service" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
nginx_ingress_port="$(kubectl -n "$nginx_ingress_namespace" get service "$nginx_ingress_service" -o jsonpath='{.spec.ports[?(@.name=="http")].port}')"

kubectl label ns "$nginx_ingress_namespace" openservicemesh.io/monitored-by="$osm_mesh_name"

kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: https-$APP_NAMESPACE
  namespace: $APP_NAMESPACE
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      proxy_ssl_name "default.dummy-logger.cluster.local";
    nginx.ingress.kubernetes.io/proxy-ssl-secret: "kube-system/osm-nginx-client-cert"
    nginx.ingress.kubernetes.io/proxy-ssl-verify: "on"
spec:  
  tls:
  - hosts:
    - $DNS
    secretName: $SECRET_NAME
  ingressClassName: nginx
  rules:
  - host: $DNS
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: dummy-logger
            port:
              number: 80
---
apiVersion: policy.openservicemesh.io/v1alpha1
kind: IngressBackend
metadata:
  name: dummy-logger
  namespace: $APP_NAMESPACE
spec:
  backends:
  - name: dummy-logger
    port:
      number: 80
      protocol: https
    tls:
      skipClientCertValidation: false
  sources:
  - kind: Service
    name: "$nginx_ingress_service"
    namespace: "$nginx_ingress_namespace"
  - kind: AuthenticatedPrincipal
    name: nginx-ingress-ingress-nginx.ingress.cluster.local
EOF

kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: http-dummy-logger
  namespace: dummy-logger
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: dummy-logger
            port:
              number: 80
---
kind: IngressBackend
apiVersion: policy.openservicemesh.io/v1alpha1
metadata:
  name: http-dummy-logger
  namespace: dummy-logger
spec:
  backends:
  - name: dummy-logger
    port:
      number: 80
      protocol: http
  sources:
  - kind: Service
    namespace: "$nginx_ingress_namespace"
    name: "$nginx_ingress_service"
EOF


curl -sI $DNS

kubectl label namespace ingress-basic cert-manager.io/disable-validation=true
helm repo add jetstack https://charts.jetstack.io

helm repo update

CERT_MANAGER_REGISTRY=quay.io
CERT_MANAGER_TAG=v1.3.1
CERT_MANAGER_IMAGE_CONTROLLER=jetstack/cert-manager-controller
CERT_MANAGER_IMAGE_WEBHOOK=jetstack/cert-manager-webhook
CERT_MANAGER_IMAGE_CAINJECTOR=jetstack/cert-manager-cainjector

# Install the cert-manager Helm chart
helm upgrade cert-manager jetstack/cert-manager \
  --namespace ingress --install \
  --version $CERT_MANAGER_TAG \
  --set installCRDs=true \
  --set image.repository=$CERT_MANAGER_REGISTRY/$CERT_MANAGER_IMAGE_CONTROLLER \
  --set image.tag=$CERT_MANAGER_TAG \
  --set webhook.image.repository=$CERT_MANAGER_REGISTRY/$CERT_MANAGER_IMAGE_WEBHOOK \
  --set webhook.image.tag=$CERT_MANAGER_TAG \
  --set cainjector.image.repository=$CERT_MANAGER_REGISTRY/$CERT_MANAGER_IMAGE_CAINJECTOR \
  --set cainjector.image.tag=$CERT_MANAGER_TAG

kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: mail@test.de
    privateKeySecretRef:
      name: letsencrypt
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: https-dummy-logger
  namespace: dummy-logger
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
spec:  
  tls:
  - hosts:
    - $DNS
    secretName: dummy-cert-secret
  ingressClassName: nginx
  rules:
  - host: $DNS
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: dummy-logger
            port:
              number: 80
EOF

kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: https-dummy-logger
  namespace: dummy-logger
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    # proxy_ssl_name for a service is of the form <service-account>.<namespace>.cluster.local
    nginx.ingress.kubernetes.io/configuration-snippet: |
      proxy_ssl_name "httpbin.httpbin.cluster.local";
    nginx.ingress.kubernetes.io/proxy-ssl-secret: "osm-system/osm-nginx-client-cert"
    nginx.ingress.kubernetes.io/proxy-ssl-verify: "on"
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: httpbin
            port:
              number: 14001
---
apiVersion: policy.openservicemesh.io/v1alpha1
kind: IngressBackend
metadata:
  name: httpbin
  namespace: httpbin
spec:
  backends:
  - name: httpbin
    port:
      number: 14001
      protocol: https
    tls:
      skipClientCertValidation: false
  sources:
  - kind: Service
    name: "$nginx_ingress_service"
    namespace: "$nginx_ingress_namespace"
  - kind: AuthenticatedPrincipal
    name: ingress-nginx.ingress.cluster.local
EOF

curl -sI http://"$DNS"/get

kubectl get secret dummy-cert-secret -n dummy-logger -o json | jq '.data | map_values(@base64d)'

openssl pkcs12 -export -in ingress-tls.crt -inkey ingress-tls.key  -out $CERT_NAME.pfx
# skip Password prompt

az keyvault certificate import --vault-name ${KEYVAULT_NAME} -n $CERT_NAME -f $CERT_NAME.pfx

cat <<EOF | kubectl apply -f -
apiVersion: secrets-store.csi.x-k8s.io/v1alpha1
kind: SecretProviderClass
metadata:
  name: ingress-tls
  namespace: ingress
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    userAssignedIdentityID: "$AKS_KUBELET_CLIENT_ID"
    keyvaultName: "$VAULT_NAME"
    cloudName: ""                   # [OPTIONAL for Azure] if not provided, azure environment will default to AzurePublicCloud
    objects:  |
      array:
        - |
          objectName: mySecret
          objectType: secret        # object types: secret, key or cert
          objectVersion: ""         # [OPTIONAL] object versions, default to latest if empty
    tenantId: "$TENANT_ID"                 # the tenant ID of the KeyVault  
EOF


cat <<EOF | kubectl apply -f -
kind: Pod
apiVersion: v1
metadata:
  name: busybox-secrets-store-inline-user-msi
  namespace: ingress
spec:
  containers:
    - name: busybox
      image: k8s.gcr.io/e2e-test-images/busybox:1.29
      command:
        - "/bin/sleep"
        - "10000"
      volumeMounts:
      - name: secrets-store01-inline
        mountPath: "/mnt/secrets-store"
        readOnly: true
  volumes:
    - name: secrets-store01-inline
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: "ingress-tls"
EOF


AD_APP_NAME="$DEPLOYMENT_NAME-msal-proxy"
APP_HOSTNAME="$DNS"
HOMEPAGE=https://$APP_HOSTNAME
IDENTIFIER_URIS=$HOMEPAGE
REPLY_URLS=https://$APP_HOSTNAME/msal/signin-oidc

CLIENT_ID=""
OBJECT_ID=""

CLIENT_ID=$(az ad app create --display-name $AD_APP_NAME --homepage $HOMEPAGE --reply-urls $REPLY_URLS --required-resource-accesses @manifest.json -o json | jq -r '.appId')
echo $CLIENT_ID

OBJECT_ID=$(az ad app show --id $CLIENT_ID -o json | jq '.objectId' -r)
echo $OBJECT_ID

az ad app update --id $OBJECT_ID --set "oauth2Permissions=[]"

# The newly registered app does not have a password.  Use "az ad app credential reset" to add password and save to a variable.
CLIENT_SECRET=$(az ad app credential reset --id $CLIENT_ID -o json | jq '.password' -r)
echo $CLIENT_SECRET

# Get your Azure AD tenant ID and save to variable
AZURE_TENANT_ID=$(az account show -o json | jq '.tenantId' -r)
echo $AZURE_TENANT_ID