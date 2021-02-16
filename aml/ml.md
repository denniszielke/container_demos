
export SET HELM_EXPERIMENTAL_OCI=1
helm chart remove amlk8s.azurecr.io/public/azureml/amlk8s/helmchart/eastus/preview/amlk8s-extension:1.0.0
helm chart pull amlk8s.azurecr.io/public/azureml/amlk8s/helmchart/eastus/preview/amlk8s-extension:1.0.0
helm chart export amlk8s.azurecr.io/public/azureml/amlk8s/helmchart/eastus/preview/amlk8s-extension:1.0.0 --destination ./install
cd install

helm install aml-compute ./amlk8s-extension -n azureml --set  RelayConnectionString="Endpoint=sb://adramak8sworkspace963585242.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=U7S2h3/WSv2HRj/LHyMlnaaLs2D0xPheSWiaIJMmUR4=;EntityPath=connection_0"


helm show chart amlk8s-extension

kubectl create ns azureml

helm install aml-compute ./amlk8s-extension -n azureml --set  RelayConnectionString="Endpoint=sb://adramak8sworkspace963585242.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=U7S2h3/WSv2HRj/LHyMlnaaLs2D0xPheSWiaIJMmUR4=;EntityPath=connection_0"
