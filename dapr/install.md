# Install
https://github.com/dapr/docs/blob/master/getting-started/environment-setup.md#installing-dapr-on-a-kubernetes-cluster

helm repo add dapr https://daprio.azurecr.io/helm/v1/repo
helm repo update
kubectl create namespace dapr-system

helm install dapr dapr/dapr --namespace dapr-system --set dapr_operator.logLevel=debug --set dapr_placement.logLevel=debug --set dapr_sidecar_injector.logLevel=debug
kubectl get pods -n dapr-system -w
helm uninstall dapr -n dapr-system


