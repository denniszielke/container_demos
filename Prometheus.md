# Install prometheus

https://itnext.io/using-prometheus-in-azure-kubernetes-service-aks-ae22cada8dd9
https://docs.microsoft.com/en-us/azure/aks/aks-ssh
add --authentication-token-webhook to /etc/default/kubelet 
sudo systemctl restart kubelet

```
helm repo add coreos https://s3-eu-west-1.amazonaws.com/coreos-charts/stable/

helm install coreos/prometheus-operator --name prometheus-operator --namespace monitoring --set rbacEnable=false

helm install coreos/kube-prometheus --name kube-prometheus --set global.rbacEnable=false --namespace monitoring 

kubectl -n kube-system create sa tiller

kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller

APP_NAME=monitoring
helm install coreos/prometheus-operator --name prometheus-operator --namespace $APP_NAME
helm install coreos/kube-prometheus --name kube-prometheus --namespace $APP_NAME

# if it fails with "Error: watch closed before Until timeout"
kubectl delete job prometheus-operator-create-sm-job -n $APP_NAME
kubectl delete job prometheus-operator-get-crd -n $APP_NAME
helm upgrade prometheus-operator coreos/prometheus-operator --namespace $APP_NAME --force

kubectl --namespace monitoring port-forward $(kubectl get pod --namespace monitoring -l prometheus=kube-prometheus -l app=prometheus -o template --template "{{(index .items 0).metadata.name}}") 9090:9090

echo username:$(kubectl get secret --namespace monitoring kube-prometheus-grafana -o jsonpath="{.data.user}"|base64 --decode;echo)
echo password:$(kubectl get secret --namespace monitoring kube-prometheus-grafana -o jsonpath="{.data.password}"|base64 --decode;echo)


kubectl --namespace monitoring port-forward $(kubectl get pod --namespace monitoring -l app=kube-prometheus-grafana -o template --template "{{(index .items 0).metadata.name}}") 3000:3000


helm delete prometheus-operator --purge
helm delete kube-prometheus --purge