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

kubectl delete serviceaccount azure-policy -n kube-system 
kubectl delete serviceaccount azure-policy-webhook-account -n kube-system 
kubectl delete role policy-pod-agent -n kube-system
kubectl delete rolebinding policy-pod-agent -n kube-system
kubectl delete clusterrole policy-agent
kubectl delete clusterrole gatekeeper-manager-role
kubectl delete ClusterRoleBinding policy-agent
kubectl delete ClusterRoleBinding gatekeeper-manager-rolebinding
kubectl delete ns gatekeeper-system      

kubectl delete crd \
  configs.config.gatekeeper.sh \
  constraintpodstatuses.status.gatekeeper.sh \
  constrainttemplatepodstatuses.status.gatekeeper.sh \
  constrainttemplates.templates.gatekeeper.sh

SUBSCRIPTION_ID=$(az account show --query id -o tsv)

helm install azure-policy-addon azure-policy/azure-policy-addon-aks-engine --set azurepolicy.env.resourceid="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP"

helm delete azure-policy-addon 

kubectl apply -f built-in-references/Kubernetes/container-require-livenessProbe/template.yaml
kubectl apply -f built-in-references/Kubernetes/container-require-livenessProbe/constraint.yaml


# yaml

kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.1/deploy/gatekeeper.yaml

kubectl delete -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml


# helm open source

kubectl create ns gatekeeper-system
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo update
helm upgrade gatekeeper gatekeeper/gatekeeper -n gatekeeper-system --install


# custom policy

kubectl logs -l control-plane=controller-manager -n gatekeeper-system

kubectl apply -f built-in-references/Kubernetes/container-require-livenessProbe/template.yaml
kubectl apply -f built-in-references/Kubernetes/container-require-livenessProbe/constraint.yaml

cat <<EOF | kubectl apply -f -
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredProbes
metadata:
  name: must-have-probes
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
  excludedNamespaces:
    - kube-system
    - gatekeeper-system
  parameters:
    probes: ["readinessProbe", "livenessProbe"]
    probeTypes: ["tcpSocket", "httpGet", "exec"]
EOF

# policy addon

policy evaluation every 15 minutes


```


az aks show --query addonProfiles.azurepolicy -g $KUBE_GROUP -n $KUBE_NAME

```

kubectl get constrainttemplates.templates.gatekeeper.sh 


kubectl get constrainttemplates.templates.gatekeeper.sh k8sazureloadbalancernopublicips -o yaml
https://store.policy.core.windows.net/kubernetes/load-balancer-no-public-ips/v1/template.yaml

kubectl get constrainttemplates.templates.gatekeeper.sh k8sazurecontainerallowedimages -o yaml    

https://store.policy.core.windows.net/kubernetes/container-allowed-images/v1/template.yaml

kubectl create namespace special
kubectl label namespace special admission.policy.azure.com/ignore=true
kubectl label namespace special control-plane=true

kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/svc-lb-logger.yaml -n special

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: centos
  namespace: special
spec:
  containers:
  - name: centos
    image: centos
    securityContext:
      privileged: true
    ports:
    - containerPort: 80
    command:
    - sleep
    - "3600"
EOF


kubectl create namespace ordinary

kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/svc-lb-logger.yaml -n ordinary

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: centos
  namespace: ordinary
spec:
  containers:
  - name: centos
    image: centos
    securityContext:
      privileged: true
    ports:
    - containerPort: 80
    command:
    - sleep
    - "3600"
EOF

kubectl get k8sazurecontainerallowedimages.constraints.gatekeeper.sh -o yaml     

labels will not deny violations, compliance still available

kubectl label namespace control-plane

admission.policy.azure.com/ignore

see violations

kubectl get k8sazurecontainernoprivilege.constraints.gatekeeper.sh  -o yaml

kubectl describe deployment dummy-logger
kubectl describe replicasets.apps dummy-logger

```