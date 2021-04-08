# Install


## Nginx

```
export INGRESS_NAMESPACE="nginx"

kubectl create ns $INGRESS_NAMESPACE


echo "create role binding"

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: dapr-secret-reader
subjects:
- kind: ServiceAccount
  name: default
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
EOF

echo "create api token"

export API_TOKEN=$(openssl rand -base64 32)

kubectl create secret generic dapr-api-token --from-literal=token="${API_TOKEN}" -n $INGRESS_NAMESPACE

cat <<EOF | kubectl apply -f -
---
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: ingress-config
  namespace: $INGRESS_NAMESPACE
spec:
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
EOF

controller:
  podAnnotations:
    dapr.io/enabled: "true" 
    dapr.io/app-id: "nginx-ingress" 
    dapr.io/app-protocol: "http"
    dapr.io/app-port: "80"
    dapr.io/api-token-secret: "dapr-api-token" 
    dapr.io/config: "ingress-config"
    dapr.io/log-as-json: "true"


echo "create ingress"

helm upgrade my-nginx-controller  nginx/nginx-ingress --install --set controller.stats.enabled=true --set controller.replicaCount=2 --set controller.service.externalTrafficPolicy=Local --set-string controller.pod.annotations.'dapr\.io/enabled'="true" --set-string controller.pod.annotations.'dapr\.io/app-id'="nginx-ingress" --set-string controller.pod.annotations.'dapr\.io/app-protocol'="http" --set-string controller.pod.annotations.'dapr\.io/app-port'="80" --set-string controller.pod.annotations.'dapr\.io/api-token-secret'="dapr-api-token" --set-string controller.pod.annotations.'dapr\.io/config'="ingress-config" --set-string controller.pod.annotations.'dapr\.io/log-as-json'="true" --namespace=$INGRESS_NAMESPACE 

helm upgrade my-nginx-controller nginx/nginx-ingress --install --set controller.stats.enabled=true --set controller.replicaCount=1 --set controller.service.externalTrafficPolicy=Local --namespace=$INGRESS_NAMESPACE

helm template my-nginx-controller nginx/nginx-ingress --set-string controller.podAnnotations.'dapr\.io/enabled'="true" --namespace=$INGRESS_NAMESPACE 

helm template my-nginx-controller nginx/nginx-ingress --set-string controller.pod.annotations.'dapr\.io/enabled'="true" --set-string controller.pod.annotations.'dapr\.io/app-id'="nginx-ingress" --set-string controller.pod.annotations.'dapr\.io/app-protocol'="http" --set-string controller.pod.annotations.'dapr\.io/app-port'="80" --set-string controller.pod.annotations.'dapr\.io/api-token-secret'="dapr-api-token" --set-string controller.pod.annotations.'dapr\.io/config'="ingress-config" --set-string controller.pod.annotations.'dapr\.io/log-as-json'="true" --namespace=$INGRESS_NAMESPACE 


export SERVICE_IP=$(kubectl get svc --namespace $INGRESS_NAMESPACE my-nginx-controller-nginx-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')


cat <<EOF | kubectl apply -f -  
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress-rules
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
    - host: $SERVICE_IP.xip.io
      http:
        paths:
          - path: /
            backend:
              serviceName: nginx-ingress-dapr
              servicePort: 80
EOF

echo "test"

export API_TOKEN=$(kubectl get secret dapr-api-token -o jsonpath="{.data.token}" -n ${INGRESS_NAMESPACE} | base64 --decode)


curl -i \
     -H "Content-type: application/json" \
     -H "dapr-api-token: ${API_TOKEN}" \
     "http://$SERVICE_IP.xip.io/v1.0/healthz"

```



