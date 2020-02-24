# Managed OpenShift
https://github.com/Azure/OpenShift
https://docs.microsoft.com/en-us/azure/aks/aad-integration


create app id and create permissions the same as for aks
```
az ad app create --display-name $OSA_CLUSTER_NAME --key-type Password --password $OSA_AAD_SECRET --identifier-uris $OSA_AAD_REPLY_URL --reply-urls $OSA_AAD_REPLY_URL
```

Define variables
```
OSA_RG_NAME=dzopenshdemo
OSA_CLUSTER_NAME=dzosa123
LOCATION=westeurope
OSA_AAD_SECRET=supersecret
OSA_AAD_ID=herebeaadclientid
OSA_AAD_TENANT=herebeaadtenant
OSA_AAD_REPLY_URL=https://$OSA_CLUSTER_NAME.$LOCATION.cloudapp.azure.com/oauth2callback/Azure%20AD
OSA_FQDN=$OSA_CLUSTER_NAME.$LOCATION.cloudapp.azure.com
OSA_ADMIN_GROUP_ID=herebeadmingroupobjectid
```

## create cluster via cli
```
az group create --name $OSA_RG_NAME --location $LOCATION

az openshift create --resource-group $OSA_RG_NAME --name $OSA_CLUSTER_NAME -l $LOCATION --fqdn $OSA_FQDN --aad-client-app-id $OSA_AAD_ID --aad-client-app-secret $OSA_AAD_SECRET --aad-tenant-id $OSA_AAD_TENANT

open https://dzosa123.westeurope.cloudapp.azure.com

oc new-app openshift/ruby:25~https://github.com/denniszielke/ruby-ex 

https://dzosa123.westeurope.cloudapp.azure.com/oauth2callback/Azure%20AD
https://openshift.454daa57a4544cc88ceb.westeurope.azmosa.io/oauth2callback/Azure%20AD
https://openshift.xxxxxxx.westeurope.azmosa.io/oauth2callback/Azure%20AD


```

## create via arm
```
az group create -n $OSA_RG_NAME -l $LOCATION

az group deployment create \
    --name openshiftmanaged \
    --resource-group $OSA_RG_NAME \
    --template-file "arm/openshift_template.json" \
    --parameters "arm/openshift_parameters.json" \
    --parameters "resourceName=$OSA_CLUSTER_NAME" \
        "location=$LOCATION" \
        "fqdn=$OSA_FQDN" \
        "servicePrincipalClientId=$OSA_AAD_ID" \
        "servicePrincipalClientSecret=$OSA_AAD_SECRET" \
        "tenantId=$OSA_AAD_TENANT" \
        "customerAdminGroupId=$OSA_ADMIN_GROUP_ID"
```


## cluster operations
```
az openshift scale --resource-group $OSA_RG_NAME --name $OSA_CLUSTER_NAME --compute-count 5

az openshift delete --resource-group $OSA_RG_NAME --name $OSA_CLUSTER_NAME 
```

## delete via arm

https://docs.microsoft.com/en-us/rest/api/resources/resourcegroups/delete


## ARO 4.3
https://github.com/Azure/ARO-RP/blob/master/docs/using-az-aro.md
