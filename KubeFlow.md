# Kubeflow

## Install
https://operatorhub.io/operator/kubeflow
```
curl -sL https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.20.0/install.sh | bash -s v0.20.0

kubectl create -f https://operatorhub.io/install/kubeflow.yaml

kubectl get csv -n operators
kubectl get pod -n operators


https://github.com/kubeflow/manifests/blob/v1.2-branch/kfdef/kfctl_azure_aad.v1.2.0.yaml
```