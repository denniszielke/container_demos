# APIM with otel


#https://github.com/open-telemetry/opentelemetry-helm-charts/commit/5a01f839474dc3556fa461b46beff6cada71bbfa#diff-d34732aba6898ffb96752242a9ff4baed96595a2d6c97c6263af690139dda368

helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts

helm repo update

cat << EOF > opentelemetry-collector-config.yml
mode: deployment
config:
  exporters:
    prometheus:
      endpoint: "0.0.0.0:8889"
      namespace: azure_apim
      send_timestamps: true
  service:
    pipelines:
      metrics:
        exporters:
        - prometheus
service:
  type: LoadBalancer
ports:
  jaeger-compact:
    enabled: false
  prom-exporter:
    enabled: true
    containerPort: 8889
    servicePort: 8889
    protocol: TCP
EOF



helm upgrade --install opentelemetry-collector --namespace azure-apim --create-namespace open-telemetry/opentelemetry-collector --values ./opentelemetry-collector-config.yml

APIM_NAME=""
APIM_URI="$APIM_NAME.configuration.azure-api.net"
APIM_KEY=""
SUBSCRIPTION_KEY="

helm repo add azure-apim-gateway https://azure.github.io/api-management-self-hosted-gateway/helm-charts/

helm repo update

helm search repo azure-apim-gateway

helm upgrade --install azure-api-management-gateway --namespace azure-apim  --create-namespace \
             --set gateway.configuration.uri="$APIM_URI" \
             --set gateway.auth.key="$APIM_KEY" \
             --set observability.opentelemetry.enabled=true \
             --set observability.opentelemetry.collector.uri=http://opentelemetry-collector:4317 \
             --set service.type=LoadBalancer \
             azure-apim-gateway/azure-api-management-gateway

kubectl get all -l app.kubernetes.io/instance=apim-gateway -n azure-apim

curl -i "http://azure-api-management-gateway.azure-apim.svc.cluster.local:8080/echo/resource?param1=sample/echo/resource?param1=sample&subscription-key=$SUBSCRIPTION_KEY"
curl -i "https://$APIM_NAME.azure-api.net/echo/resource?param1=sample/echo/resource?param1=sample&subscription-key=$SUBSCRIPTION_KEY"
curl -i "https://$APIM_NAME.azure-api.net/ping?&subscription-key=$SUBSCRIPTION_KEY"
curl -i "http://10.2.0.84:8080/ping?subscription-key=$SUBSCRIPTION_KEY" -H "Ocp-Apim-Trace: true"
curl -i "http://azure-api-management-gateway.azure-apim.svc.cluster.local:8080/echo/resource?param1=sample&subscription-key=$SUBSCRIPTION_KEY"
curl -i "http://azure-api-management-gateway.azure-apim.svc.cluster.local:8080/apis/cluster-dummy-logger/ping"
curl -i "http://azure-api-management-gateway.azure-apim.svc.cluster.local:8080/cluster-dummy-logger/ping"

https://techcommunity.microsoft.com/t5/azure-observability-blog/visualizing-data-in-realtime-with-azure-managed-grafana/ba-p/3606421


# NOTE: Before deploying to a production environment, please review the documentation -> https://aka.ms/self-hosted-gateway-production
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: america-env
data:
  config.service.endpoint: ".configuration.azure-api.net"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: america
spec:
  replicas: 1
  selector:
    matchLabels:
      app: america
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 25%
  template:
    metadata:
      labels:
        app: america
    spec:
      terminationGracePeriodSeconds: 60
      containers:
      - name: america
        image: mcr.microsoft.com/azure-api-management/gateway:v2
        ports:
        - name: http
          containerPort: 8080
        - name: https
          containerPort: 8081
        readinessProbe:
          httpGet:
            path: /status-0123456789abcdef
            port: http
            scheme: HTTP
          initialDelaySeconds: 0
          periodSeconds: 5
          failureThreshold: 3
          successThreshold: 1
        env:
        - name: config.service.auth
          valueFrom:
            secretKeyRef:
              name: america-token
              key: value
        envFrom:
        - configMapRef:
            name: america-env
---
apiVersion: v1
kind: Service
metadata:
  name: america
spec:
  type: LoadBalancer
  externalTrafficPolicy: Local
  ports:
  - name: http
    port: 80
    targetPort: 8080
  - name: https
    port: 443
    targetPort: 8081
  selector:
    app: america