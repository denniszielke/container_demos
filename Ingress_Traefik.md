
# Install traefik

https://github.com/thomseddon/traefik-forward-auth
https://github.com/helm/charts/tree/master/stable/traefik

```
kubectl apply -f https://raw.githubusercontent.com/containous/traefik/v1.7/examples/k8s/traefik-rbac.yaml
```

## create public ip

```
KUBE_GROUP=security
KUBE_NAME=pspcluster
DNS_NAME=dzapis
IP_NAME=traefik-ingress-pip
NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv)

az network public-ip create \
    --resource-group $NODE_GROUP \
    --name $IP_NAME \
    --dns-name $DNS_NAME \
    --allocation-method static

DNS=$(az network public-ip show --resource-group $NODE_GROUP --name $IP_NAME --query dnsSettings.fqdn --output tsv)
IP=$(az network public-ip show --resource-group $NODE_GROUP --name $IP_NAME --query ipAddress --output tsv)

helm install stable/traefik --name traefikingress --namespace kube-system --set dashboard.enabled=true,dashboard.domain=dashboard.localhost,rbac.enabled=true,loadBalancerIP=$IP,externalTrafficPolicy=Local,replicas=2,ssl.enabled=true,ssl.permanentRedirect=true,ssl.insecureSkipVerify=true,acme.enabled=true,acme.challengeType=http-01,acme.email=$MY_ID,acme.staging=false

helm upgrade traefikingress stable/traefik --install --namespace kube-system --set dashboard.enabled=true,dashboard.domain=dashboard.localhost,rbac.enabled=true,loadBalancerIP=$IP,externalIP=$IP,externalTrafficPolicy=Local,replicas=2,ssl.enabled=true,ssl.permanentRedirect=true,ssl.insecureSkipVerify=true,acme.enabled=true,acme.challengeType=http-01,acme.email=$MY_ID,acme.staging=false

kubectl -n kube-system port-forward $(kubectl -n kube-system get pod -l app=traefik -o jsonpath='{.items[0].metadata.name}') 8080:8080

annotations:
https://docs.traefik.io/configuration/backends/kubernetes/#general-annotations


kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/depl-logger.yaml
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/svc-cluster-logger.yaml
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/pod-logger.yaml

kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/yaml/calc-min-depl.yaml

kubectl get -n colors deploy -o yaml \
  | linkerd inject - \
  | kubectl apply -f -

DNS=13.95.69.233.xip.io

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: dummy-logger
  annotations:
    kubernetes.io/ingress.class: traefik
    ingress.kubernetes.io/whitelist-x-forwarded-for: "true"
    traefik.ingress.kubernetes.io/redirect-permanent: "true"
    traefik.ingress.kubernetes.io/preserve-host: "true"
    traefik.ingress.kubernetes.io/rewrite-target: /
    traefik.ingress.kubernetes.io/rate-limit: |
      extractorfunc: client.ip
      rateset:
        rateset1:
          period: 3s
          average: 3
          burst: 5
spec:
  rules:
  - host: $DNS
    http:
      paths:
      - path: /
        backend:
          serviceName: nginx
          servicePort: 80
      - path: /calc
        backend:
          serviceName: calc-frontend-svc
          servicePort: 80
EOF

for i in `seq 1 10000`; do time curl -s http://$DNS > /dev/null; done

for i in `seq 1 10000`; do time curl -s http://13.95.69.233.xip.io/color; done
DNS=13.95.69.233.xip.io/color


cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/rewrite-target: /
    traefik.ingress.kubernetes.io/service-weights: |
      color-blue-svc: 90%
      color-green-svc: 10%
  name: colors
  namespace: colors
spec:
  rules:
  - host: $DNS
    http:
      paths:
      - backend:
          serviceName: color-blue-svc
          servicePort: 80
        path: /color
      - backend:
          serviceName: color-green-svc
          servicePort: 80
        path: /color
EOF
```

## Traefik Oauth2Proxy
https://geek-cookbook.funkypenguin.co.nz/reference/oauth_proxy/

configure app for azure 
https://pusher.github.io/oauth2_proxy/auth-configuration#azure-auth-provider

use the following sign-on url
https://dzapis.westeurope.cloudapp.azure.com
https://dzapis.westeurope.cloudapp.azure.com/oauth2/callback

github
```
generate cookie secret:
python -c 'import os,base64; print base64.b64encode(os.urandom(16))'
API_CLIENT_ID=
API_CLIENT_SECRET=
API_COOKIE_SECRET=
```

```

helm install --name authproxy \
    --namespace=kube-system \
    --set config.clientID=$API_CLIENT_ID \
    --set config.clientSecret=$API_CLIENT_SECRET \
    --set config.cookieSecret=$API_COOKIE_SECRET \
    --set extraArgs.provider=github \
    --set resources.limits.cpu=200m \
    stable/oauth2-proxy

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/rewrite-target: /
  name: auth2
  namespace: kube-system
spec:
  rules:
  - host: dzapis.westeurope.cloudapp.azure.com
    http:
      paths:
      - backend:
          serviceName: authproxy-oauth2-proxy
          servicePort: 80
        path: /oauth2
EOF
```

http://authproxy-oauth2-proxy.kube-system.svc.cluster.local:80/auth
http://authproxy-oauth2-proxy.kube-system.svc.cluster.local:80/start


configure forward authentication
https://docs.traefik.io/configuration/entrypoints/#forward-authentication
https://raw.githubusercontent.com/helm/charts/master/stable/traefik/values.yaml

```
helm upgrade mytraefik stable/traefik --values yaml/traefik.yaml --namespace kube-system --set dashboard.enabled=true,dashboard.domain=dashboard.localhost,rbac.enabled=true,loadBalancerIP=$IP,externalTrafficPolicy=Local,replicas=2,ssl.enabled=true,ssl.permanentRedirect=true,ssl.insecureSkipVerify=true,acme.enabled=true,acme.challengeType=http-01,acme.email=$MY_ID,acme.staging=false,forwardAuth.address=http://authproxy-oauth2-proxy.kube-system.svc.cluster.local:80
```