# APIG

SUBSCRIPTION_ID="892cd868-0dde-415d-9178-fa99dd1d04a5"
RESOURCE_GROUP="dzapig5"
GATEWAY_NAME="azapig5"
GATEWAY_SUBNET_NAME="apig"
VNET_NAME="dzapig5-vnet"
AKS_CLUSTER_NAME="dzapig5"

BACKEND_SUBNET_ID=$(az network vnet subnet show --vnet-name $VNET_NAME --name $GATEWAY_SUBNET_NAME --resource-group $RESOURCE_GROUP --query id --output tsv)
AGENT_APP_ID=$(az aks show --subscription $SUBSCRIPTION_ID --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME --query identityProfile.kubeletidentity.clientId --output tsv)


az deployment group create --resource-group $RESOURCE_GROUP \
                           --template-file ./deploy/create-api-gateway.json \
                           --parameters gatewayName=$GATEWAY_NAME \
                                        backendSubnetResourceId=$BACKEND_SUBNET_ID \
                                        agentApplicationId=$AGENT_APP_ID gatewayInstances=3

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: backend
  labels:
    app: backend
    service: backend
spec:
  ports:
    - name: http
      port: 8080
      targetPort: 8080
  selector:
    app: backend
EOF

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
      version: v1
  template:
    metadata:
      labels:
        app: backend
        version: v1
    spec:
      containers:
        - image: swaggerapi/petstore
          imagePullPolicy: IfNotPresent
          name: backend
          ports:
            - containerPort: 8080
          env:
            - name: SWAGGER_HOST
              value: "https://gateway-hostname-here"
            - name: SWAGGER_URL
              value: "https://gateway-hostname-here"
            - name: SWAGGER_BASE_PATH
              value: "/v2"
          resources:
            limits:
              cpu: "200m"
              memory: "512Mi"
            requests:
              cpu: "50m"
              memory: "128Mi"
EOF

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-world
spec:
  ingressClassName: azure-api-gateway
  rules:
    - http:
        paths:
          - pathType: Prefix
            path: "/"
            backend:
              service:
                name: backend
                port:
                  number: 8080
EOF

export GATEWAY_HOSTNAME=$(az rest --method get --uri /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ApiManagement/gateways/$GATEWAY_NAME\?api-version=2023-09-01-preview | jq -r '.properties.frontend.defaultHostname')

# Replace the gateway hostname in the sample-app.yaml file and apply the configurations
cat ./deploy/sample-app.yaml | sed "s/gateway-hostname-here/${GATEWAY_HOSTNAME}/g" | kubectl apply -f -