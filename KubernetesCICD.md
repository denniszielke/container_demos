# Kubernetes CICD

## Kubernetes deployment via VSTS
https://dgkanatsios.com/2017/05/29/creating-a-cicd-pipeline-on-azure-container-services-with-kubernetes-and-visual-studio-team-services/

## Install Istio
https://readon.ly/post/2017-05-25-deploy-istio-to-azure-container-service/

Verify installation
```
export PODNAME=$(kubectl get pods | grep "grafana" | awk '{print $1}')
kubectl port-forward $PODNAME 3000:3000
```
http://localhost:3000/dashboard/db/istio-dashboard


## Configure VSTS CICD
https://blogs.technet.microsoft.com/livedevopsinjapan/2017/07/19/istio-cicd-pipeline-for-vsts/

