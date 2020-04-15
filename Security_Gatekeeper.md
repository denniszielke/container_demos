# Gatekeeper V2
https://docs.microsoft.com/en-us/azure/governance/policy/concepts/rego-for-aks
https://docs.microsoft.com/en-us/azure/governance/policy/concepts/effects#enforceopaconstraint

AKS-Engine
https://github.com/Azure/azure-policy/tree/master/extensions/policy-addon-kubernetes/helm-charts/azure-policy-addon-aks-engine

Config
https://raw.githubusercontent.com/Azure/azure-policy/master/built-in-references/Kubernetes/gatekeeper-opa-sync.yaml

Gatekeeper deploy
https://github.com/open-policy-agent/gatekeeper/blob/master/deploy/gatekeeper.yaml

https://github.com/open-policy-agent/gatekeeper#replicating-data

PSP Library:
https://github.com/open-policy-agent/gatekeeper/tree/master/library

## AKS

az aks enable-addons --addons azure-policy --name $KUBE_NAME --resource-group $KUBE_GROUP
az aks disable-addons --addons azure-policy --name $KUBE_NAME --resource-group $KUBE_GROUP

az aks list --query '[].{Name:name, ClientId:servicePrincipalProfile.clientId}' -o table


# AKS Engine
https://docs.microsoft.com/en-gb/azure/governance/policy/concepts/aks-engine

SERVICE_PRINCIPAL_ID=$(az aks show --name $KUBE_NAME --resource-group $KUBE_GROUP --query servicePrincipalProfile -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

az role assignment create --assignee $SERVICE_PRINCIPAL_ID --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP" --role "Policy Insights Data Writer (Preview)"


deploy gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml

kubectl label namespaces kube-system control-plane=controller-manager

kubectl apply -f https://raw.githubusercontent.com/Azure/azure-policy/master/built-in-references/Kubernetes/gatekeeper-opa-sync.yaml

helm github:
https://github.com/Azure/azure-policy/tree/master/extensions/policy-addon-kubernetes
helm repo add azure-policy https://raw.githubusercontent.com/Azure/azure-policy/master/extensions/policy-addon-kubernetes/helm-charts
helm repo update
helm upgrade azure-policy-addon azure-policy/azure-policy-addon-aks-engine --namespace=kube-system  --install --set azurepolicy.env.resourceid="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP"


cleanup policy addon
kubectl delete serviceaccount azure-policy -n kube-system 
kubectl delete clusterrole policy-agent


azure policy logs
kubectl logs $(kubectl -n kube-system get pods -l app=azure-policy --output=name) -n kube-system

gatekeeper logs
kubectl logs $(kubectl -n gatekeeper-system get pods -l gatekeeper.sh/system=yes --output=name) -n gatekeeper-system


delete gatekeeper
kubectl delete -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml
helm delete azure-policy-addon --namespace=kube-system
