# Install Operator Framework

## Install
```

kubectl apply -f https://github.com/jetstack/cert-manager/releases/latest/download/cert-manager.yaml

kubectl apply -f bestpractices/operators.yaml

AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv) # here enter your subscription id
AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)

AZURE_CLIENT_ID=$(az ad sp show --id $KUBE_NAME -o json | jq -r '.[0].appId')
if [ "$AZURE_CLIENT_ID" == "" ]; then
   AZURE_CLIENT_ID=$(az ad sp create-for-rbac --name $KUBE_NAME   --scopes /subscriptions/$AZURE_SUBSCRIPTION_ID --role contributor -o json | jq -r '.appId')
fi

AZURE_CLIENT_SECRET=$(az ad app credential reset --append --id $AZURE_CLIENT_ID -o json | jq '.password' -r)


cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: aso-controller-settings
  namespace: azureoperator-system
stringData:
  AZURE_SUBSCRIPTION_ID: "$AZURE_SUBSCRIPTION_ID"
  AZURE_TENANT_ID: "$AZURE_TENANT_ID"
  AZURE_CLIENT_ID: "$AZURE_CLIENT_ID"
  AZURE_CLIENT_SECRET: "$AZURE_CLIENT_SECRET"
EOF

az keyvault set-policy -n $VAULT_NAME --secret-permissions set get list --spn $AZURE_CLIENT_ID

cat <<EOF | kubectl apply -f -
apiVersion: microsoft.resources.azure.com/v1alpha1api20200601
kind: ResourceGroup
metadata:
  name: foo2019
spec:
  location: $LOCATION
EOF

cat <<EOF | kubectl apply -f -
apiVersion: microsoft.storage.azure.com/v1alpha1api20210401
kind: StorageAccount
metadata:
  name: samplekubestorage
  namespace: default
spec:
  location: westcentralus
  kind: BlobStorage
  sku:
    name: Standard_LRS
  owner:
    name: foo2019
  accessTier: Hot
EOF

kubectl get StorageAccount
kubectl delete StorageAccount samplekubestorage

kubectl get ResourceGroup
kubectl delete ResourceGroup foo2019
```