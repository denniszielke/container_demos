# Set up otel in AKS

```
AI_CONNECTIONSTRING=$(az resource show -g $KUBE_GROUP -n $KUBE_NAME-ai --resource-type "Microsoft.Insights/components" --query properties.ConnectionString -o tsv | tr -d '[:space:]')

echo $AI_CONNECTIONSTRING

cat <<EOF | kubectl apply -f -
apiVersion: azmon.app.monitoring/v1
kind: appmonitoringconfig
metadata:
  name: appmonitor
  namespace: otel-demo
spec:
  autoInstrumentationPlatforms: [ Java ] # NodeJs, DotNet, Java
  aiConnectionString: $AI_CONNECTIONSTRING
EOF


cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: petclinic
  namespace: otel-demo
spec:
  selector:
    matchLabels:
      app: spring-petclinic
  replicas: 1
  template:
    metadata:
      labels:
        app: spring-petclinic
    spec:
      containers:
      - name: app
        image: ghcr.io/pavolloffay/spring-petclinic:latest
        ports:
          - containerPort: 8080
        env:       
          - name: "APPLICATIONINSIGHTS_ROLE_NAME"
            value: "petclinic"
---
apiVersion: v1
kind: Service
metadata:
  name: petclinic
  namespace: otel-demo
  labels:
    app: spring-petclinic
spec:
  selector:
    app: spring-petclinic
  type: LoadBalancer
  ports:
   - port: 80
     targetPort: 8080
EOF

```