# App routing

https://learn.microsoft.com/en-us/azure/aks/app-routing-nginx-configuration

## DNS Zone
```
DNS_ZONE_ID=$(az network dns zone list -g blobs -o tsv --query "[].id")
DNS_ZONE=$(az network dns zone list -g blobs -o tsv --query "[].name")

az aks approuting zone add -g $KUBE_GROUP -n $KUBE_NAME --ids=${DNS_ZONE_ID} --attach-zones
```
## Cert

```
VAULT_NAME=dzkv$KUBE_NAME 
APP=app1
DNS=app1.$DNS_ZONE

openssl req -new -x509 -nodes -out aks-ingress-tls.crt -keyout aks-ingress-tls.key -subj "/CN=$DNS" -addext "subjectAltName=DNS:$DNS"

openssl pkcs12 -export -in aks-ingress-tls.crt -inkey aks-ingress-tls.key -out aks-ingress-tls.pfx

az keyvault certificate import --vault-name $VAULT_NAME -n $APP -f aks-ingress-tls.pfx

az keyvault certificate show --vault-name $VAULT_NAME -n $APP --query "id" --output tsv

VAULT_ID=$(az keyvault show -g $KUBE_GROUP -n $VAULT_NAME -o tsv --query id)

CERT_ID=$(az keyvault certificate show --vault-name $VAULT_NAME -n $APP --query "id" --output tsv)


az aks approuting update -g $KUBE_GROUP -n $KUBE_NAME --enable-kv --attach-kv ${VAULT_ID}
```

## Ingress

```
kubectl apply -f - <<EOF
apiVersion: approuting.kubernetes.azure.com/v1alpha1
kind: NginxIngressController
metadata:
  name: nginx-static
spec:
  ingressClassName: nginx-static
  controllerNamePrefix: nginx-static
  loadBalancerAnnotations: 
    service.beta.kubernetes.io/azure-pip-name: "myIngressPublicIP"
    service.beta.kubernetes.io/azure-load-balancer-resource-group: "myNetworkResourceGroup"


kubectl create ns dummy-logger
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/depl-logger.yaml -n dummy-logger

kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/svc-cluster-logger.yaml -n dummy-logger

kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    kubernetes.azure.com/tls-cert-keyvault-uri: $CERT_ID
  name: dummy-ingress
  namespace: dummy-logger
spec:
  ingressClassName: webapprouting.kubernetes.azure.com
  rules:
  - host: $DNS
    http:
      paths:
      - backend:
          service:
            name: dummy-logger-cluster
            port:
              number: 80
        path: /
        pathType: Prefix
  tls:
  - hosts:
    - $DNS
    secretName: keyvault-dummy-ingress
EOF
```

## Monitoring

kubectl get configmap ama-metrics-settings-configmap -n kube-system -o yaml > ama-metrics-settings-configmap-backup.yaml