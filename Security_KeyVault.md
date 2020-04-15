# Kubernetes using aad-pod-identity to access azure key vault
https://github.com/Azure/aad-pod-identity
https://blog.jcorioland.io/archives/2018/09/05/azure-aks-active-directory-managed-identities.html

0. Variables

```
KUBE_GROUP=kubesdemo
KUBE_NAME=dzkubeaks
LOCATION="westeurope"
SUBSCRIPTION_ID=
AAD_APP_ID=
AAD_APP_SECRET=
AAD_CLIENT_ID=
TENANT_ID=
YOUR_SSH_KEY=$(cat ~/.ssh/id_rsa.pub)
SERVICE_PRINCIPAL_ID=
SERVICE_PRINCIPAL_SECRET=
ADMIN_GROUP_ID=
MY_OBJECT_ID=
KUBE_ADMIN_ID=
READER_USER_ID=

VAULT_GROUP="MC_aksv2_aksv2_westus2"
VAULT_NAME="dzbyokdemo"
MSA_NAME="mykvidentity"
MSA_CLIENT_ID=""
MSA_PRINCIPAL_ID=""
SECRET_NAME="mySecret"
SECRET_VERSION=""
KEY_NAME="mykey"
STORAGE_NAME="dzbyokdemo"
```

1. create key vault
```
az group create -n $VAULT_GROUP -l $LOCATION
az keyvault create -n $VAULT_NAME -g $VAULT_GROUP -l $LOCATION
az keyvault create -n $VAULT_NAME -g $VAULT_GROUP -l $LOCATION --enable-soft-delete true --enable-purge-protection true --sku premium
az keyvault list -g $VAULT_GROUP -o table --query [].{Name:name,ResourceGroup:resourceGroup,PurgeProtection:properties.enablePurgeProtection,SoftDelete:properties.enableSoftDelete}
```

2. add dummy secret
```
az keyvault secret set -n $SECRET_NAME --vault-name $VAULT_NAME --value MySuperSecretThatIDontWantToShareWithYou!
```
list secrets
```
az keyvault secret list --vault-name $VAULT_NAME -o table
```

add a key
```
az keyvault key create -n $KEY_NAME --vault-name $VAULT_NAME --kty RSA --ops encrypt decrypt wrapKey unwrapKey sign verify --protection hsm --size 2048
```
list keys
```
az keyvault key list --vault-name $VAULT_NAME -o table
```

3. create kubernetes crds
```
kubectl create -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/deployment-rbac.yaml
```

4. create managed identiy for pod
```
az identity create -n $MSA_NAME -g $VAULT_GROUP

```
5. assign managed identity reader role in keyvault
```
KEYVAULT_PERMISSION="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$VAULT_GROUP/providers/Microsoft.KeyVault/vaults/$VAULT_NAME"
az role assignment create --role "Reader" --assignee $MSA_PRINCIPAL_ID --scope $KEYVAULT_PERMISSION
```

do this if the identity is not in the same resource groups as the aks nodes

```
az keyvault set-policy -n $VAULT_NAME --secret-permissions get list --spn $MSA_CLIENT_ID

KUBE_PERMISSION="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$VAULT_GROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$MSA_NAME"
az role assignment create --role "Managed Identity Operator" --assignee $SERVICE_PRINCIPAL_ID --scope $KUBE_PERMISSION
```

assign permissions on node groups for msi
```
az role assignment create --role "Contributor" --assignee $MSA_PRINCIPAL_ID -g $KUBE_GROUP
```

6. bind to crds

```
cat <<EOF | kubectl create -f -
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentity
metadata:
  name: $MSA_NAME
spec:
  type: 0
  ResourceID: /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$VAULT_GROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$MSA_NAME
  ClientID: $MSA_CLIENT_ID
EOF
```

7. bind pod identity

```
cat <<EOF | kubectl create -f -
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentityBinding
metadata:
  name: sample-binding
spec:
  AzureIdentity: $MSA_NAME
  Selector: keyvaultsampleidentity
EOF
```

8. deploy sample app

```
cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  labels:
    app: demo
    aadpodidbinding: demo
  name: demo
  namespace: default
spec:
  template:
    metadata:
      labels:
        app: keyvaultsampleidentity
        aadpodidbinding: keyvaultsampleidentity
    spec:
      containers:
      - name: demo
        image: "mcr.microsoft.com/k8s/aad-pod-identity/demo:1.2"
        imagePullPolicy: Always
        args:
          - "--subscriptionid=$SUBSCRIPTION_ID"
          - "--clientid=$MSA_CLIENT_ID"
          - "--resourcegroup=$VAULT_GROUP"
          - "--aad-resourcename=https://vault.azure.net"
          # TO SPECIFY NAME OF RESOURCE TO GRANT TOKEN ADD --aad-resourcename
          # this demo defaults aad-resourcename to https://management.azure.com/
          # e.g. - "--aad-resourcename=https://vault.azure.net"
        env:
        - name: MY_POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: MY_POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: MY_POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
EOF
```

key vault demo
```

VAULT_NAME=dzdevkeyvault
AZURE_KEYVAULT_SECRET_NAME=mysupersecret
SECRET_VERSION=

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: centos
  labels:
    app: keyvaultsample
    aadpodidbinding: keyvaultsampleidentity
spec:
  containers:
  - name: centoss
    image: centos
    ports:
    - containerPort: 80
    command:
    - sleep
    - "3600"
EOF

curl http://127.0.0.1:2579/host/token/?resource=https://vault.azure.net -H "podname: centos" -H "podns: default"
curl http://127.0.0.1:2579/host/token/?resource=https://vault.azure.net -H "podname: keyvaultsample-65b7d4d4f4-bspd7" -H "podns: default"

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: keyvaultsample
    aadpodidbinding: keyvaultsampleidentity
  name: keyvaultsample
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: keyvaultsample
  template:
    metadata:
      labels:
        app: keyvaultsample
        aadpodidbinding: keyvaultsampleidentity
      name: keyvaultsample
    spec:
      containers:
      - name: keyvaultsample
        image: jcorioland/keyvault-aad-pod-identity:1.6
        env:
        - name: AZURE_KEYVAULT_NAME
          value: $VAULT_NAME
        - name: AZURE_KEYVAULT_SECRET_NAME
          value: $SECRET_NAME
        - name: AZURE_KEYVAULT_SECRET_VERSION
          value: $SECRET_VERSION
---
apiVersion: v1
kind: Service
metadata:
  name: keyvaultsample
  namespace: default
spec:
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: keyvaultsample
  type: LoadBalancer
EOF
```

Cleanup
```
kubectl delete pods --selector=component=mic

PODNAME=`kubectl get pods --namespace=${NAMESPACE} --selector="app=tf-hub" --output=template --template="{{with index .items 0}}{{.metadata.name}}{{end}}"`
```

https://github.com/Azure/azure-libraries-for-java/blob/master/AUTH.md

https://github.com/Azure/azure-libraries-for-java/tree/master/azure-mgmt-msi/src

## create storage with byok key


1. create key vault
```
az group create -n $VAULT_GROUP -l $LOCATION
az keyvault create -n $VAULT_NAME -g $VAULT_GROUP -l $LOCATION --enable-soft-delete true --enable-purge-protection true --sku premium
az keyvault list -g $VAULT_GROUP -o table --query [].{Name:name,ResourceGroup:resourceGroup,PurgeProtection:properties.enablePurgeProtection,SoftDelete:properties.enableSoftDelete}
```

2. add a key
```
az keyvault key create -n $KEY_NAME --vault-name $VAULT_NAME --kty RSA --ops encrypt decrypt wrapKey unwrapKey sign verify --protection hsm --size 2048
```
list keys
```
az keyvault key list --vault-name $VAULT_NAME -o table
```

3. create storage account
```
az storage account create -n $STORAGE_NAME -g $VAULT_GROUP --https-only true --encryption-services table queue blob file --assign-identity
```

4. get storage account identity
```
az storage account show -g $VAULT_GROUP -n $STORAGE_NAME --query identity.principalId
```

5. set policy for storage identity to access keyvault
```
az keyvault set-policy -n $VAULT_NAME --object-id cae12840-2557-4469-909e-c29283a82c45 --key-permissions get wrapkey unwrapkey
```

6. Create or Update your Azure Storage Account to use your new keys from your Key Vault:
```
az storage account update -g $VAULT_GROUP -n $STORAGE_NAME --encryption-key-name $KEY_NAME --encryption-key-source Microsoft.KeyVault --encryption-key-vault https://$VAULT_NAME.vault.azure.net --encryption-key-version 2ce0b736baff47a4b5691edc2c53a597 --encryption-services blob file queue table

az acr create -n dzdemoky23 -g $VAULT_GROUP --sku Classic --location $LOCATION --storage-account-name $STORAGE_NAME
```

## CSI 
https://github.com/deislabs/secrets-store-csi-driver/tree/master/pkg/providers/azure
```
SERVICE_PRINCIPAL_ID=$AZDO_SERVICE_PRINCIPAL_ID
SERVICE_PRINCIPAL_SECRET=$AKS_SERVICE_PRINCIPAL_SECRET
VAULT_GROUP=dztenix-888
AZURE_KEYVAULT_NAME=dztenix-888-vault
LOCATION=westeurope
TENANT_ID=$(az account show --query tenantId -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

kubectl create secret generic secrets-store-creds --from-literal clientid=$SERVICE_PRINCIPAL_ID --from-literal clientsecret=$SERVICE_PRINCIPAL_SECRET

az role assignment create --role Reader --assignee $SERVICE_PRINCIPAL_ID --scope /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$VAULT_GROUP/providers/Microsoft.KeyVault/vaults/$AZURE_KEYVAULT_NAME

az keyvault set-policy -n $AZURE_KEYVAULT_NAME --key-permissions get --spn $SERVICE_PRINCIPAL_ID
az keyvault set-policy -n $AZURE_KEYVAULT_NAME --secret-permissions get --spn $SERVICE_PRINCIPAL_ID
az keyvault set-policy -n $AZURE_KEYVAULT_NAME --certificate-permissions get --spn $SERVICE_PRINCIPAL_ID

cd /Users/$USER/hack/secrets-store-csi-driver

kubectl create ns csi-secrets-store

helm upgrade csi-drver charts/secrets-store-csi-driver --namespace csi-secrets-store --install

kubectl create ns dummy

cat <<EOF | kubectl apply -f -
apiVersion: secrets-store.csi.x-k8s.io/v1alpha1
kind: SecretProviderClass
metadata:
  name: azure-kvname1
spec:
  provider: azure                   # accepted provider options: azure or vault
  parameters:
    usePodIdentity: "false"         # [OPTIONAL for Azure] if not provided, will default to "false"
    keyvaultName: "$AZURE_KEYVAULT_NAME"          # the name of the KeyVault
    objects:  |
      array:
        - |
          objectName: acr-name
          objectType: secret        # object types: secret, key or cert
        - |
          objectName: aks-group
          objectType: secret
    resourceGroup: "$VAULT_GROUP"            # [REQUIRED for version < 0.0.4] the resource group of the KeyVault
    subscriptionId: "$SUBSCRIPTION_ID"         # [REQUIRED for version < 0.0.4] the subscription ID of the KeyVault
    tenantId: "$TENANT_ID"                 # the tenant ID of the KeyVault
EOF

cat <<EOF | kubectl apply -f -
kind: Pod
apiVersion: v1
metadata:
  name: nginx-default
spec:
  containers:
    - image: nginx
      name: nginx
      volumeMounts:
      - name: secrets-store-inline
        mountPath: "/mnt/secrets-store"
        readOnly: true
  volumes:
    - name: secrets-store-inline
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: "azure-kvname1"
        nodePublishSecretRef:
          name: secrets-store-creds
EOF

kubectl exec -it nginx-secrets-store-inline -n dummy -- /bin/sh

```

## df

cat <<EOF | kubectl apply -f -
kind: Pod
apiVersion: v1
metadata:
  name: nginx-secrets-store-inline
spec:
  containers:
  - image: nginx
    name: nginx
    volumeMounts:
    - name: secrets-store-inline
      mountPath: "/mnt/secrets-store"
      readOnly: true
  volumes:
    - name: secrets-store-inline
      csi:
        driver: secrets-store.csi.k8s.com
        readOnly: true
        volumeAttributes:
          providerName: "azure"
          usePodIdentity: "false"          # [OPTIONAL] if not provided, will default to "false"
          keyvaultName: "$VAULT_NAME"                # the name of the KeyVault
          objects:  |
            array:
              - |
                objectName: mysupersecret
                objectType: secret        # object types: secret, key or cert
                objectVersion: ""         # [OPTIONAL] object versions, default to latest if empty
          resourceGroup: "$VAULT_GROUP"               # the resource group of the KeyVault
          subscriptionId: "$SUBSCRIPTION_ID"              # the subscription ID of the KeyVault
          tenantId: "$TENANT_ID"                    # the tenant ID of the KeyVault
EOF

```


```
az identity create -n keyvaultidentity -g $VAULT_GROUP
KUBE_PERMISSION="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$VAULT_GROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/keyvaultidentity"
az role assignment create --role "Managed Identity Operator" --assignee $SERVICE_PRINCIPAL_ID --scope $KUBE_PERMISSION

MSI_ID=$(az identity show -n keyvaultidentity -g $VAULT_GROUP --query clientId --output tsv)

az role assignment create --role Reader --assignee $MSI_ID --scope /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$VAULT_GROUP/providers/Microsoft.KeyVault/vaults/$VAULT_NAME

# set policy to access keys in your keyvault
az keyvault set-policy -n $VAULT_NAME --key-permissions get --spn $MSI_ID
# set policy to access secrets in your keyvault
az keyvault set-policy -n $VAULT_NAME --secret-permissions get --spn $MSI_ID
# set policy to access certs in your keyvault
az keyvault set-policy -n $VAULT_NAME --certificate-permissions get --spn $MSI_ID


cat <<EOF | kubectl apply -f -
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentity
metadata:
  name: keyvaultidentity
spec:
  type: 0
  ResourceID: /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$VAULT_GROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/keyvaultidentity
  ClientID: $MSI_ID
EOF

cat <<EOF | kubectl apply -f -
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentityBinding
metadata:
  name: keyvaultidentity-binding
spec:
  AzureIdentity: keyvaultidentity
  Selector: keyvaultidentity
EOF

az keyvault secret set -n mysupersecret --vault-name $VAULT_NAME --value MySuperSecretThatIDontWantToShareWithYou!

cat <<EOF | kubectl apply -f -
kind: Pod
apiVersion: v1
metadata:
  name: nginx-secrets-store-inline-pod-identity
  labels:
    aadpodidbinding: "keyvaultidentity"
spec:
  containers:
  - image: nginx
    name: nginx
    volumeMounts:
    - name: secrets-store-inline
      mountPath: "/mnt/secrets-store"
      readOnly: true
  volumes:
    - name: secrets-store-inline
      csi:
        driver: secrets-store.csi.k8s.com
        readOnly: true
        volumeAttributes:
          providerName: "azure"
          usePodIdentity: "true"          # [OPTIONAL] if not provided, will default to "false"
          keyvaultName: "$VAULT_NAME"                # the name of the KeyVault
          objects:  |
            array:
              - |
                objectName: mysupersecret
                objectType: secret        # object types: secret, key or cert
                objectVersion: ""         # [OPTIONAL] object versions, default to latest if empty
          resourceGroup: "$VAULT_GROUP"               # the resource group of the KeyVault
          subscriptionId: "$SUBSCRIPTION_ID"              # the subscription ID of the KeyVault
          tenantId: "$TENANT_ID"                    # the tenant ID of the KeyVault
EOF

kubectl exec -it nginx-secrets-store-inline-pod-identity cat /kvmnt/testsecret
```