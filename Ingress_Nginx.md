# Nginx

## Install nginx
```
IP_NAME=nginx-ingress-pip

az network public-ip create --resource-group $NODE_GROUP --name $IP_NAME --sku Standard --allocation-method static

IP=$(az network public-ip show --resource-group $NODE_GROUP --name $IP_NAME --query ipAddress --output tsv)

helm repo add nginx https://helm.nginx.com/stable
helm search repo nginx-ingress


kubectl create ns nginx
helm upgrade my-ingress-controller stable/nginx-ingress --install --set controller.service.loadBalancerIP="$IP" --set controller.stats.enabled=true --set controller.replicaCount=2 --set controller.service.externalTrafficPolicy=Local --namespace=nginx

helm install nginx stable/nginx-ingress \
    --namespace nginx --set controller.service.loadBalancerIP="$IP" --set controller.service.externalTrafficPolicy=Local \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux

helm upgrade my-ingress-controller stable/nginx-ingress --install --set controller.stats.enabled=true --set controller.replicaCount=2 --set controller.service.externalTrafficPolicy=Local --namespace=nginx

```


## Lets encrypt

```
kubectl apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.12/deploy/manifests/00-crds.yaml --namespace kube-system


kubectl create namespace cert-manager

helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager --namespace ingress-basic --version v0.12.0 jetstack/cert-manager --set ingressShim.defaultIssuerName=letsencrypt --set ingressShim.defaultIssuerKind=ClusterIssuer


helm upgrade cert-manager --namespace cert-manager --install jetstack/cert-manager --set ingressShim.defaultIssuerName=letsencrypt-prod --set ingressShim.defaultIssuerKind=ClusterIssuer



deploy dumms
```
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/pod-logger.yaml

kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/svc-int-logger.yaml

```

create cert manager cluster issuer for stage or prod
```
DNS=demo71.westeurope.cloudapp.azure.com

cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt
  namespace: ingress-basic
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $MY_USER_ID
    privateKeySecretRef:
      name: letsencrypt
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1alpha2
kind: Issuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $MY_USER_ID
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - selector: {}
      http01:
        ingress:
          class: nginx
EOF

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: calculator-ingress
  namespace: calculator
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  tls:
  - hosts:
    - dtdevtool.westeurope.cloudapp.azure.com
    secretName: tls-secret
  rules:
  - host: dtdevtool.westeurope.cloudapp.azure.com
    http:
      paths:
      - backend:
          serviceName: calc1-multicalculatorv3-frontend-svc
          servicePort: 80
        path: /
EOF


cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: hello-world-ingress
  namespace: ingress-basic
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  tls:
  - hosts:
    - 51.124.57.228.xip.io
    secretName: tls-secret
  rules:
  - host: 51.124.57.228.xip.io
    http:
      paths:
      - backend:
          serviceName: dummy-logger
          servicePort: 80
        path: /
EOF

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: dummy-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - $DNS
    secretName: dns-tls
  rules:
  - host: $DNS
    http:
      paths:
      - path: /
        backend:
          serviceName: dummy-logger-int-lb
          servicePort: 80
EOF

```
