# Install

```
TENANT_ID=
API_APP_NAME=
API_APP_ID=
API_APP_URI_ID=
API_APP_SECRET=
```

## Nginx

```
INGRESS_NAMESPACE="nginx"
DNS="dzapps1.westeurope.cloudapp.azure.com"
APP_NAMESPACE="loggers"

kubectl create ns $INGRESS_NAMESPACE
kubectl create ns $APP_NAMESPACE

controller:
  podAnnotations:
    dapr.io/enabled: "true" 
    dapr.io/app-id: "nginx" 
    dapr.io/app-protocol: "http"
    dapr.io/app-port: "80"
    dapr.io/api-token-secret: "dapr-api-token" 
    dapr.io/config: "ingress-config"
    dapr.io/log-as-json: "true"


echo "create ingress"

helm upgrade nginx-controller nginx/nginx-ingress --install --set controller.stats.enabled=true --set controller.replicaCount=1 --set controller.service.externalTrafficPolicy=Local --set-string controller.pod.annotations.'dapr\.io/enabled'="true" --set-string controller.pod.annotations.'dapr\.io/app-id'="nginx" --set-string controller.pod.annotations.'dapr\.io/app-protocol'="http" --set-string controller.pod.annotations.'dapr\.io/app-port'="80" --set-string controller.pod.annotations.'dapr\.io/port'="80" --namespace=$INGRESS_NAMESPACE 

SERVICE_IP=$(kubectl get svc --namespace $INGRESS_NAMESPACE nginx-controller-nginx-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

cat <<EOF | kubectl apply -f -  
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dapr-ingress
  namespace: $INGRESS_NAMESPACE
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
    - host: $DNS
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-dapr 
                port:
                  number: 80
          - path: /v1.0/invoke
            pathType: Prefix
            backend:
              service:
                name: nginx-dapr 
                port:
                  number: 80
EOF

cat <<EOF | kubectl apply -f -  
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: dapr-ingress
  namespace: $INGRESS_NAMESPACE
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  tls:
  - hosts:
    - $DNS
    secretName: tls-secret
  rules:
    - host: $DNS
      http:
        paths:
        - backend:
            serviceName: nginx-dapr
            servicePort: 80
          path: /
          pathType: Prefix
        - backend:
            serviceName: nginx-dapr
            servicePort: 80
          path: /v1.0/invoke
          pathType: Prefix
EOF

cat <<EOF | kubectl apply -f -  
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: dapr-ingress
  namespace: $INGRESS_NAMESPACE
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
    - host: $DNS
      http:
        paths:
        - backend:
            serviceName: nginx-dapr
            servicePort: 80
          path: /
          pathType: Prefix
        - backend:
            serviceName: nginx-dapr
            servicePort: 80
          path: /v1.0/invoke
          pathType: Prefix
EOF

echo "test"

echo "without auth token"
curl -i \
     -H "Content-type: application/json" \
     "http://$DNS/v1.0/healthz"

curl -i \
     -H "Content-type: application/json" \
     "http://$DNS/v1.0/healthz"

echo "with auth token"
curl -i \
     -H "Content-type: application/json" \
     -H "dapr-api-token: ${API_TOKEN}" \
     "http://$DNS/v1.0/healthz"


cat <<EOF | kubectl apply -f -  
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dummy-logger
  namespace: $INGRESS_NAMESPACE
spec:
  replicas: 1 
  minReadySeconds: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1 
  selector:
    matchLabels:
      app: dummy-logger
  template:
    metadata:
      labels:
        app: dummy-logger
      annotations:
        dapr.io/enabled: "true"
        dapr.io/app-id: "dummy-logger"
        dapr.io/app-port: "80"
    spec:
      containers:
      - name: dummy-logger
        image: denniszielke/dummy-logger:latest  
        ports:
        - containerPort: 80
        imagePullPolicy: Always   
        resources:
          requests:
            memory: "58Mi"
            cpu: "50m"
          limits:
            memory: "156Mi"
            cpu: "100m"
EOF

curl -i \
     -H "Content-type: application/json" \
     "http://$DNS/v1.0/invoke/dummy-logger.$INGRESS_NAMESPACE/method/ping"


curl -i \
     -H "Content-type: application/json" \
     "http://$DNS/v1.0/invoke/dummy-logger.$INGRESS_NAMESPACE/method/api/log"

echo "create role binding"

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
  namespace: $INGRESS_NAMESPACE
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: dapr-secret-reader
  namespace: $INGRESS_NAMESPACE
subjects:
- kind: ServiceAccount
  name: default
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
EOF

echo "create api token"

API_TOKEN=$(openssl rand -base64 32)

kubectl create secret generic dapr-api-token --from-literal=token="${API_TOKEN}" -n $INGRESS_NAMESPACE

cat <<EOF | kubectl apply -f -
---
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: ingress-config
  namespace: $INGRESS_NAMESPACE
spec:
  mtls:
    enabled: true
    workloadCertTTL: "24h"
    allowedClockSkew: "15m"
  tracing:
    samplingRate: "1"
  secrets:
    scopes:
      - storeName: kubernetes
        defaultAccess: deny
        allowedSecrets: ["dapr-api-token"]
---
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: tracing
  namespace: $INGRESS_NAMESPACE
spec:
  tracing:
    samplingRate: "1"
    zipkin:
      endpointAddress: "http://otel-collector.default.svc.cluster.local:9411/api/v2/spans"
EOF

helm upgrade nginx-controller  nginx/nginx-ingress --install --set controller.stats.enabled=true --set controller.replicaCount=1 --set controller.service.externalTrafficPolicy=Local --set-string controller.pod.annotations.'dapr\.io/enabled'="true" --set-string controller.pod.annotations.'dapr\.io/app-id'="nginx" --set-string controller.pod.annotations.'dapr\.io/app-protocol'="http" --set-string controller.pod.annotations.'dapr\.io/app-port'="80" --set-string controller.pod.annotations.'dapr\.io/port'="80" --set-string controller.pod.annotations.'dapr\.io/api-token-secret'="dapr-api-token" --set-string controller.pod.annotations.'dapr\.io/config'="ingress-config" --set-string controller.pod.annotations.'dapr\.io/log-as-json'="true" --namespace=$INGRESS_NAMESPACE 

kubectl create secret generic dapr-api-token --from-literal=token="${API_TOKEN}" -n $APP_NAMESPACE

API_TOKEN=$(kubectl get secret dapr-api-token -o jsonpath="{.data.token}" -n ${APP_NAMESPACE} | base64 --decode)
API_TOKEN=$(kubectl get secret dapr-api-token -o jsonpath="{.data.token}" -n ${INGRESS_NAMESPACE} | base64 --decode)

cat <<EOF | kubectl apply -f -  
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dummy-logger
  namespace: $APP_NAMESPACE
spec:
  replicas: 1 
  minReadySeconds: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1 
  selector:
    matchLabels:
      app: dummy-logger
  template:
    metadata:
      labels:
        app: dummy-logger
      annotations:
        dapr.io/enabled: "true"
        dapr.io/app-id: "dummy-logger"
        dapr.io/app-port: "80"
    spec:
      containers:
      - name: dummy-logger
        image: denniszielke/dummy-logger:latest  
        ports:
        - containerPort: 80
        imagePullPolicy: Always   
        resources:
          requests:
            memory: "58Mi"
            cpu: "50m"
          limits:
            memory: "156Mi"
            cpu: "100m"
EOF

curl -i \
     -H "Content-type: application/json" \
     "http://$DNS/v1.0/invoke/dummy-logger.$APP_NAMESPACE/method/ping"

curl -i \
     -H "Content-type: application/json" \
     -H "dapr-api-token: ${API_TOKEN}" \
     "http://$DNS/v1.0/invoke/dummy-logger.$APP_NAMESPACE/method/ping"

curl -i \
     -H "Content-type: application/json" \
     "http://$DNS/v1.0/invoke/dummy-logger.$APP_NAMESPACE/method/api/log"

curl -i -X POST \
     -H "Content-type: application/json" \
     -H "dapr-api-token: ${API_TOKEN}" \
     "http://$DNS/v1.0/invoke/dummy-logger.$APP_NAMESPACE/method/api/log"

echo "hard lock down traffic from ingress to app"

cat <<EOF | kubectl apply -f -  
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: dummy-logger-config
  namespace: $APP_NAMESPACE
spec:
  mtls:
    enabled: true
    workloadCertTTL: "24h"
    allowedClockSkew: "15m"
  tracing:
    samplingRate: "1"
  secrets:
    scopes:
      - storeName: kubernetes
        defaultAccess: deny
        allowedSecrets: ["dapr-api-token"]
  accessControl:
    defaultAction: deny
    trustDomain: "loggers"
    policies:
    - appId: nginx
      defaultAction: deny 
      trustDomain: "public"
      namespace: "$INGRESS_NAMESPACE"
      operations:
      - name: /api/log
        httpVerb: ["POST"] 
        action: allow
      - name: /ping
        httpVerb: ["GET"] 
        action: deny
EOF

cat <<EOF | kubectl apply -f -  
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dummy-logger-auth-policy
  namespace: $APP_NAMESPACE
spec:
  replicas: 1 
  minReadySeconds: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1 
  selector:
    matchLabels:
      app: dummy-logger
  template:
    metadata:
      labels:
        app: dummy-logger
      annotations:
        dapr.io/enabled: "true"
        dapr.io/app-id: "dummy-logger-auth-policy"
        dapr.io/app-port: "80"
        dapr.io/config: "dummy-logger-config"
        dapr.io/log-as-json: "true"
        dapr.io/log-level: "debug"
        dapr.io/api-token-secret: "dapr-api-token" 
    spec:
      containers:
      - name: dummy-logger
        image: denniszielke/dummy-logger:latest  
        ports:
        - containerPort: 80
        imagePullPolicy: Always   
        resources:
          requests:
            memory: "58Mi"
            cpu: "50m"
          limits:
            memory: "156Mi"
            cpu: "100m"
EOF

curl -i \
     -H "Content-type: application/json" \
     -H "dapr-api-token: ${API_TOKEN}" \
     "http://$DNS/v1.0/invoke/dummy-logger-auth-policy.$APP_NAMESPACE/method/ping"


curl -i -X POST \
     -H "Content-type: application/json" \
     -H "dapr-api-token: ${API_TOKEN}" \
     "http://$DNS/v1.0/invoke/dummy-logger-auth-policy.$APP_NAMESPACE/method/api/log"


echo "aad client credentials validation"
https://docs.dapr.io/operations/security/oauth/

TENANT_ID=$(az account show --query tenantId -o tsv)
TENANT_NAME=microsoft.onmicrosoft.com
API_APP_NAME=dapr-demo-app1
API_APP_ID=
API_APP_URI_ID=https://$TENANT_NAME/$API_APP_NAME


API_APP_ID=$(az ad app create --display-name $API_APP_NAME --homepage http://localhost --identifier-uris $API_APP_URI_ID  -o json | jq -r '.appId')

URI_REDIRECT="http://localhost:80/v1.0/invoke/dummy-logger-oauth-client/method/headers"

API_APP_SECRET=$(az ad app credential reset --id $API_APP_ID -o json | jq '.password' -r)

open https://login.microsoftonline.com/$TENANT_ID/adminconsent?client_id=$API_APP_ID&state=12345&redirect_uri=http://localhost/$API_APP_NAME/permissions

curl -X POST -H "Content-Type: application/x-www-form-urlencoded" \
    --data "client_id=$API_APP_ID" \
    --data "resource=$API_APP_URI_ID" \
    --data-urlencode "client_secret=$API_APP_SECRET" \
    --data "grant_type=client_credentials" \
     "https://login.microsoftonline.com/$TENANT_ID/oauth2/token"

echo "bearer validation"

cat <<EOF | kubectl apply -f -  
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: bearer-token
  namespace: $APP_NAMESPACE
spec:
  type: middleware.http.bearer
  version: v1
  metadata:
  - name: clientId
    value: "$API_APP_ID"
  - name: issuerURL
    value: "https://sts.windows.net/$TENANT_ID/"
EOF

cat <<EOF | kubectl apply -f -  
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: bearer-config
  namespace: $APP_NAMESPACE
spec:
  httpPipeline:
    handlers:
    - name: bearer-token
      type: middleware.http.bearer
EOF

cat <<EOF | kubectl apply -f -  
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dummy-logger-bearer
  namespace: $APP_NAMESPACE
spec:
  replicas: 1 
  minReadySeconds: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1 
  selector:
    matchLabels:
      app: dummy-logger
  template:
    metadata:
      labels:
        app: dummy-logger
      annotations:
        dapr.io/enabled: "true"
        dapr.io/app-id: "dummy-logger-bearer"
        dapr.io/app-port: "80"
        dapr.io/config: "bearer-config"
        dapr.io/log-as-json: "true"
        dapr.io/log-level: "debug"
    spec:
      containers:
      - name: dummy-logger
        image: denniszielke/dummy-logger:latest  
        ports:
        - containerPort: 80
        imagePullPolicy: Always   
EOF

curl -i \
     -H "Content-type: application/json" \
     -H "Authorization: Bearer $TOKEN" \
     "http://$DNS/v1.0/invoke/dummy-logger-bearer.$APP_NAMESPACE/method/headers"

curl -i \
     -H "Content-type: application/json" \
     -H "Authorization: Bearer bla" \
     "http://$DNS/v1.0/invoke/dummy-logger-bearer.$APP_NAMESPACE/method/headers"

cat <<EOF | kubectl apply -f -  
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: oauth2
  namespace: $APP_NAMESPACE
spec:
  type: middleware.http.oauth2
  version: v1
  metadata:
  - name: clientId
    value: "$API_APP_ID"
  - name: clientSecret
    value: "$API_APP_SECRET"
  - name: scopes
    value: "Do.All"
  - name: authURL
    value: "https://login.microsoftonline.com/$TENANT_ID/oauth2/authorize"
  - name: tokenURL
    value: "https://login.microsoftonline.com/$TENANT_ID/oauth2/token"
  - name: redirectURL
    value: "http://$DNS/v1.0/invoke/dummy-logger-oauth2.$APP_NAMESPACE/method/headers"
  - name: authHeaderName
    value: "Authorization"
  - name: forceHTTPS
    value: "false"
EOF

cat <<EOF | kubectl apply -f -  
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: oauth2-pipeline
  namespace: $APP_NAMESPACE
spec:
  httpPipeline:
    handlers:
    - name: oauth2
      type: middleware.http.oauth2
EOF

cat <<EOF | kubectl apply -f -  
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dummy-logger-oauth2
  namespace: $APP_NAMESPACE
spec:
  replicas: 1 
  minReadySeconds: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1 
  selector:
    matchLabels:
      app: dummy-logger
  template:
    metadata:
      labels:
        app: dummy-logger
      annotations:
        dapr.io/enabled: "true"
        dapr.io/app-id: "dummy-logger-oauth2"
        dapr.io/app-port: "80"
        dapr.io/config: "oauth2-pipeline"
        dapr.io/log-as-json: "true"
        dapr.io/log-level: "debug"
        dapr.io/api-token-secret: "dapr-api-token" 
    spec:
      containers:
      - name: dummy-logger
        image: denniszielke/dummy-logger:latest  
        ports:
        - containerPort: 80
        imagePullPolicy: Always   
        resources:
          requests:
            memory: "58Mi"
            cpu: "50m"
          limits:
            memory: "156Mi"
            cpu: "100m"
EOF

cat <<EOF | kubectl apply -f -  
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: my-oauth-component
  namespace: $APP_NAMESPACE
spec:
  type: middleware.http.oauth2clientcredentials
  version: v1
  metadata:
  - name: clientId
    value: "$API_APP_ID"
  - name: clientSecret
    value: "$API_APP_SECRET"
  - name: scopes
    value: "Do.All"
  - name: tokenURL
    value: "https://login.microsoftonline.com/$TENANT_ID/oauth2/token"
  - name: headerName
    value: "Authorization"
  - name: authStyle
    value: "0"
EOF

cat <<EOF | kubectl apply -f -  
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: ingress-config
  namespace: $INGRESS_NAMESPACE
spec:
  mtls:
    enabled: true
    workloadCertTTL: "24h"
    allowedClockSkew: "15m"
  httpPipeline:
    handlers:
    - name: my-oauth-component
      type: middleware.http.oauth2clientcredentials
EOF

cat <<EOF | kubectl apply -f -  
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: my-oauth-component
  namespace: $INGRESS_NAMESPACE
spec:
  type: middleware.http.oauth2clientcredentials
  version: v1
  metadata:
  - name: clientId
    value: "$API_APP_ID"
  - name: clientSecret
    value: "$API_APP_SECRET"
  - name: scopes
    value: "Do.All"
  - name: tokenURL
    value: "https://login.microsoftonline.com/$TENANT_ID/oauth2/token"
  - name: headerName
    value: "Authorization"
  - name: authStyle
    value: "0"
EOF

cat <<EOF | kubectl apply -f -  
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: dummy-logger-oauth2-pipeline
  namespace: $APP_NAMESPACE
spec:
  mtls:
    enabled: true
    workloadCertTTL: "24h"
    allowedClockSkew: "15m"
  httpPipeline:
    handlers:
    - name: my-oauth-component
      type: middleware.http.oauth2clientcredentials
EOF

cat <<EOF | kubectl apply -f -  
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: bearer-token
  namespace: $APP_NAMESPACE
spec:
  type: middleware.http.bearer
  version: v1
  metadata:
  - name: clientId
    value: "$API_APP_ID"
  - name: issuerURL
    value: "https://sts.windows.net/f9175784-360c-4d85-8f75-dc042fbde38a"
EOF

cat <<EOF | kubectl apply -f -  
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: dummy-logger-oauth2-pipeline
  namespace: $APP_NAMESPACE
spec:
  httpPipeline:
    handlers:
    - name: bearer-token
      type: middleware.http.bearer
EOF

cat <<EOF | kubectl apply -f -  
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dummy-logger-oauth-client
  namespace: $APP_NAMESPACE
spec:
  replicas: 1 
  minReadySeconds: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1 
  selector:
    matchLabels:
      app: dummy-logger
  template:
    metadata:
      labels:
        app: dummy-logger
      annotations:
        dapr.io/enabled: "true"
        dapr.io/app-id: "dummy-logger-oauth-client"
        dapr.io/app-port: "80"
        dapr.io/config: "dummy-logger-oauth2-pipeline"
        dapr.io/log-as-json: "true"
        dapr.io/log-level: "debug"
        dapr.io/api-token-secret: "dapr-api-token" 
    spec:
      containers:
      - name: dummy-logger
        image: denniszielke/dummy-logger:latest  
        ports:
        - containerPort: 80
        imagePullPolicy: Always   
        resources:
          requests:
            memory: "58Mi"
            cpu: "50m"
          limits:
            memory: "156Mi"
            cpu: "100m"
EOF

curl -i \
     -H "Content-type: application/json" \
     -H "Authorization: Bearer $TOKEN" \
     -H "dapr-api-token: ${API_TOKEN}" \
     "http://$DNS/v1.0/invoke/dummy-logger-oauth-client.$APP_NAMESPACE/method/headers"

curl -i \
     -H "Content-type: application/json" \
     -H "dapr-api-token: ${API_TOKEN}" \
     "http://$DNS/v1.0/invoke/dummy-logger-oauth-client.$APP_NAMESPACE/method/headers"

```