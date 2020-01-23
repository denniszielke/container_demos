# Nginx

## Install nginx
```
helm repo add nginx https://helm.nginx.com/stable
helm search repo nginx-ingress
helm upgrade my-ingress-controller stable/nginx-ingress --install --set controller.stats.enabled=true --set controller.replicaCount=2 --set controller.service.externalTrafficPolicy=Local


helm upgrade my-ingress-controller stable/nginx-ingress --install --set controller.stats.enabled=true --set controller.replicaCount=2 --set controller.service.externalTrafficPolicy=Local

```


## Lets encrypt

```
kubectl create namespace cert-manager

helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade cert-manager --namespace cert-manager --install --version v0.12.0 jetstack/cert-manager --set ingressShim.defaultIssuerName=letsencrypt-prod --set ingressShim.defaultIssuerKind=ClusterIssuer

helm install stable/cert-manager --name cert-issuer-manager --namespace kube-system --set ingressShim.defaultIssuerName=letsencrypt-prod --set ingressShim.defaultIssuerKind=ClusterIssuer



deploy dumms
```
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/pod-logger.yaml

kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/svc-int-logger.yaml

```

create cert manager cluster issuer for stage or prod
```
DNS=dzapis.westeurope.cloudapp.azure.com

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
