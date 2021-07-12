

```
echo 'installing nginx....'


NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv)

IP_NAME=nginx-ingress-pip

az network public-ip create --resource-group $NODE_GROUP --name $IP_NAME --sku Standard --allocation-method static --dns-name dznginx

IP=$(az network public-ip show --resource-group $NODE_GROUP --name $IP_NAME --query ipAddress --output tsv)

helm repo add nginx https://helm.nginx.com/stable
helm search repo nginx-ingress


kubectl create ns nginx
helm upgrade my-ingress-controller nginx/nginx-ingress --install --set controller.service.loadBalancerIP="$IP" --set controller.stats.enabled=true --set controller.replicaCount=2 --set controller.service.externalTrafficPolicy=Local --namespace=nginx


echo 'installing cert-manager'

kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.1.0/cert-manager.yaml

kubectl create namespace cert-manager

kubectl label namespace cert-manager cert-manager.io/disable-validation=true

helm repo add jetstack https://charts.jetstack.io

helm repo update

helm upgrade --install \
  cert-manager \
  --namespace cert-manager \
  --version v1.1.0 \
  --set installCRDs=true \
  jetstack/cert-manager

cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: dummy1@email.com
    privateKeySecretRef:
      name: letsencrypt
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

echo 'creating ingress objects'

kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/depl-logger.yaml
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/svc-cluster-logger.yaml

kubectl apply -f - <<EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
name: appgw-dummy-ingress
annotations:
    kubernetes.io/ingress.class: azure/application-gateway
    certmanager.k8s.io/cluster-issuer: letsencrypt
spec:
tls:
- hosts:
    - <PLACEHOLDERS.COM>
    secretName: guestbook-secret-name
rules:
- host: <PLACEHOLDERS.COM>
    http:
    paths:
    - backend:
        serviceName: frontend
        servicePort: 80
EOF

NGINXDNS=$(az network public-ip show --resource-group $NODE_GROUP --name $IP_NAME --query dnsSettings.fqdn --output tsv)

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: nginx-dummy-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  tls:
  - hosts:
    - $NGINXDNS
    secretName: nginx-secret
  rules:
  - host: $NGINXDNS
    http:
      paths:
      - backend:
          serviceName: nginx
          servicePort: 80
        path: /
EOF


kubectl apply -f - <<EOF
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: bookbuyer-ingress
  namespace: bookbuyer
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
    - host: dzapps.westcentralus.cloudapp.azure.com
      http:
        paths:
        - path: /
          backend:
            serviceName: bookbuyer
            servicePort: 14001
  backend:
    serviceName: bookbuyer
    servicePort: 14001
EOF

kubectl apply -f - <<EOF
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: bookbuyer-ingress
  namespace: bookbuyer
  annotations:
    kubernetes.io/ingress.class: nginx

spec:

  rules:
    - host: bookbuyer.contoso.com
      http:
        paths:
        - path: /
          backend:
            serviceName: bookbuyer
            servicePort: 14001

  backend:
    serviceName: bookbuyer
    servicePort: 14001
EOF


curl -H 'Host: bookbuyer.contoso.com' http://dzapps.westcentralus.cloudapp.azure.com/
```