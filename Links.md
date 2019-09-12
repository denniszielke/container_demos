Public Release Notes:
https://aka.ms/aks/releasenotes 
Public Roadmap:
http://aka.ms/aks/roadmap
Public Previews:
https://aka.ms/aks/previewfeatures

AKS Release:
https://github.com/Azure/AKS/releases
https://github.com/Azure/AKS/blob/master/CHANGELOG.md

AKS VHD Release Page:
https://github.com/Azure/aks-engine/tree/master/releases/vhd-notes
Packer script:
https://github.com/Azure/aks-engine/blob/master/packer/install-dependencies.sh

https://relnotes.k8s.io/

See all aks vhd version
```
az vm image list --publisher microsoft-aks --all -o table
```

AKS CIS Status:
https://github.com/Azure/aks-engine/projects/7

Kubernetes azure cloud provider:
https://github.com/Azure/container-compute-upstream/projects/1#card-18238708 

ACR Roadmap:
https://github.com/Azure/acr/blob/master/docs/acr-roadmap.md 

OMS Docker Images:
https://github.com/Microsoft/OMS-docker/tree/aks-engine

AKS ARM Template:
https://docs.microsoft.com/en-us/azure/templates/microsoft.containerservice/2019-02-01/managedclusters
https://docs.microsoft.com/en-us/azure/templates/microsoft.containerservice/2019-06-01/managedclusters

Review docs:
https://github.com/MicrosoftDocs/azure-docs/tree/master/articles/aks
https://review.docs.microsoft.com/en-us/azure/aks/?branch=pr-en-us-67074
https://review.docs.microsoft.com/en-us/azure/templates/microsoft.containerservice/2019-02-01/managedclusters?branch=master

Preview cli:
https://github.com/Azure/azure-cli-extensions/tree/master/src/

Azure Load Balancer annotations:
https://github.com/kubernetes/cloud-provider-azure/blob/master/docs/services/README.md

- Azure Dev Spaces -> GA https://azure.microsoft.com/en-us/blog/introducing-dev-spaces-for-aks/ 
- AKS Authenticated IP for AKS API Server -> Public Preview https://docs.microsoft.com/en-us/azure/aks/api-server-authorized-ip-ranges
- AKS Azure Monitor BUILD updates https://azure.microsoft.com/en-us/blog/what-s-new-in-azure-monitor/ 
- AKS Azure Policy for AKS -> Public Preview https://docs.microsoft.com/en-gb/azure/governance/policy/overview
- AKS Functions | KEDA - Kubernetes-based Event-Driven Autoscaling https://github.com/kedacore/keda
- AKS Network policy for AKS pods -> GA https://docs.microsoft.com/en-us/azure/aks/use-network-policies 
- AKS Node Pools + Zones -> Public Preview https://docs.microsoft.com/en-us/azure/aks/use-multiple-node-pools
- AKS Autoscaler -> Public Preview https://docs.microsoft.com/en-us/azure/aks/cluster-autoscaler
- AKS Pod Security Policies -> Public Preview https://docs.microsoft.com/en-us/azure/aks/use-pod-security-policies
- AKS Virtual Nodes -> GA https://docs.microsoft.com/en-us/azure/aks/virtual-nodes-cli 
- Container Registry | Public Preview - HELM https://azure.microsoft.com/en-us/updates/azure-container-registry-helm-repositories-public-preview/
- Container Registry | Service Endpoints Public Preview https://docs.microsoft.com/en-us/azure/container-registry/container-registry-vnet

Keda scaler:
https://github.com/kedacore/keda/wiki/Scaler-prioritization

Spring cloud:
https://github.com/Azure/azure-managed-service-for-spring-cloud-docs

## Addons extras
Getting a public ip per node:
Using a function : https://github.com/dgkanatsios/AksNodePublicIP
Using a daemonset :https://github.com/dgkanatsios/AksNodePublicIPController