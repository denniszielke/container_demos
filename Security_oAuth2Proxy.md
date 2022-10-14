# Setting up oauth2 on your ingress
https://github.com/helm/charts/tree/master/stable/oauth2-proxy
https://geek-cookbook.funkypenguin.co.nz/reference/oauth_proxy/

Requirements
- nginx ingress controller deployed with dns
- trusted ssl certificate (letsencrypt-prod) on your dns
- use https://github.com/buzzfeed/sso instead of oauthproxy
- https://github.com/pusher/oauth2_proxy

sample for azure ad
https://github.com/brbarnett/k8s-aad-auth/tree/master/k8s-manifests

## Register an app

Using github auth:
https://github.com/settings/applications/new

Using azure ad:
https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-create-service-principal-portal#create-an-azure-active-directory-application

use the following sign-on url
https://$DNSNAME.westeurope.cloudapp.azure.com/oauth2/callback
https://$DNSNAME.westeurope.cloudapp.azure.com/oauth2

azuread
```
API_CLIENT_ID=
API_CLIENT_SECRET=
AZURE_TENANT_ID=
API_COOKIE_SECRET=
```

github
```
API_CLIENT_ID=
API_CLIENT_SECRET=
API_COOKIE_SECRET=
```

generate cookie secret:
python -c 'import os,base64; print base64.b64encode(os.urandom(16))'

## Deploy oauth2 proxy

for github
```
helm install --name authproxy \
    --namespace=kube-system \
    --set config.clientID=$API_CLIENT_ID \
    --set config.clientSecret=$API_CLIENT_SECRET \
    --set config.cookieSecret=$API_COOKIE_SECRET \
    --set extraArgs.provider=github \
    stable/oauth2-proxy
````

for azure ad
```
helm install --name authproxy \
    --namespace=kube-system \
    --set config.clientID=$API_CLIENT_ID \
    --set config.clientSecret=$API_CLIENT_SECRET \
    --set config.cookieSecret=$API_COOKIE_SECRET \
    --set extraArgs.provider=azure \
    stable/oauth2-proxy

```

```
set args
      - args:
        - --provider=azure
        - --email-domain=.com
        - --upstream=file:///dev/null
        - --http-address=0.0.0.0:4180
        - --azure-tenant=$AZURE_TENANT_ID
```

set up without helm chart

```
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oauth2-proxy
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: oauth2-proxy
  template:
    metadata:
      labels:
        app: oauth2-proxy
    spec:
      containers:
      - args:
        - --provider=azure
        - --email-domain=microsoft.com
        - --upstream=file:///dev/null
        - --http-address=0.0.0.0:4180
        - --azure-tenant=$AZURE_TENANT_ID
        env:
          - name: OAUTH2_PROXY_CLIENT_ID
            value: $API_CLIENT_ID
          - name: OAUTH2_PROXY_CLIENT_SECRET
            value: $API_CLIENT_SECRET
          - name: OAUTH2_PROXY_COOKIE_SECRET
            value: $API_COOKIE_SECRET
        image: docker.io/colemickens/oauth2_proxy:latest
        imagePullPolicy: Always
        name: oauth2-proxy
        ports:
        - containerPort: 4180
          protocol: TCP
EOF

cat <<EOF | kubectl create -f -
apiVersion: v1
kind: Service
metadata:
  name: oauth2-proxy
  namespace: kube-system
spec:
  ports:
  - name: http
    port: 4180
    protocol: TCP
    targetPort: 4180
  selector:
    app: oauth2-proxy
EOF

cat <<EOF | kubectl create -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: oauth2-proxy-ingress
  namespace: kube-system
  annotations:
    kubernetes.io/ingress.class: nginx
    kubernetes.io/tls-acme: "true"
spec:
  tls:
  - hosts:
    - $DNS
    secretName: hello-tls-secret
  rules:
  - host: $DNS
    http:
      paths:
      - path: /oauth2
        backend:
          serviceName: oauth2-proxy
          servicePort: 4180
EOF

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-auth
  annotations:
    kubernetes.io/ingress.class: nginx
    kubernetes.io/tls-acme: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/auth-url: "https://\$host/oauth2/auth"
    nginx.ingress.kubernetes.io/auth-signin: "https://\$host/oauth2/start"
    #nginx.ingress.kubernetes.io/auth-url: "http://oauth2-proxy.kube-system.svc.cluster.local:80/oauth2/auth"
    #nginx.ingress.kubernetes.io/auth-signin: "http://\$host/oauth2/start?rd=\$request_uri"
spec:
  tls:
    - hosts:
      - $DNS
      secretName: hello-tls-secret
  rules:
  - host: $DNS
    http:
      paths:
      - backend:
          serviceName: hello-app
          servicePort: 80
        path: /hello-auth
EOF

#### old

create the ingress with oauth2 support
```
cat <<EOF | kubectl create -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: authproxy-ingress
  namespace: kube-system
  annotations:
    kubernetes.io/ingress.class: nginx
    kubernetes.io/tls-acme: "true"
spec:
  tls:
  - hosts:
    - $DNS
    secretName: hello-tls-secret
  rules:
  - host: $DNS
    http:
      paths:
      - backend:
          serviceName: authproxy-oauth2-proxy
          servicePort: 80
        path: /oauth2
EOF
```

Create dummy app
```
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/aci-helloworld/helloapp.yaml
kubectl expose deployment hello-app
```

Deploy ingress for service

```
cat <<EOF | kubectl create -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-external-oauth2
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
    certmanager.k8s.io/cluster-issuer: letsencrypt-prod
    kubernetes.io/ingress.class: nginx
    kubernetes.io/tls-acme: "true"
    nginx.ingress.kubernetes.io/auth-url: "http://authproxy-oauth2-proxy.kube-system.svc.cluster.local:80/oauth2/auth"
    nginx.ingress.kubernetes.io/auth-signin: "http://\$host/oauth2/start?rd=\$request_uri"
spec:
  tls:
  - hosts:
    - dzapi.westus.cloudapp.azure.com
    secretName: hello-tls-secret
  rules:
  - host: dzapi.westus.cloudapp.azure.com
    http:
      paths:
      - backend:
          serviceName: hello-app
          servicePort: 80
        path: /demo
EOF
```

a reload of the backend and ingress controller may be required


cleanup
```
kubectl delete ingress hello-external-oauth2
kubectl delete deployment hello-app
kubectl delete service hello-app
kubectl delete ingress authproxy-ingress -n kube-system 
helm delete authproxy --purge
```