# Rancher
https://rancher.com/docs/rancher/v2.x/en/installation/k8s-install/helm-rancher/


helm repo add rancher-latest https://releases.rancher.com/server-charts/latest


kubectl create namespace cattle-system

DNS=kvdns.eastus.cloudapp.azure.com


helm upgrade rancher rancher-latest/rancher \
  --namespace cattle-system --install \
  --set hostname=$DNS