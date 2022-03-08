https://github.com/mohmdnofal/aks-best-practices/blob/master/stateful_workloads/zrs/README.md


cat <<EOF | kubectl apply -f -
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: zrs-class
provisioner: disk.csi.azure.com
parameters:
  skuname: Premium_ZRS 
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
EOF

kubectl apply -f https://raw.githubusercontent.com/mohmdnofal/aks-best-practices/master/stateful_workloads/zrs/mysql-configmap.yaml

kubectl apply -f https://raw.githubusercontent.com/mohmdnofal/aks-best-practices/master/stateful_workloads/zrs/mysql-services.yaml

kubectl apply -f https://raw.githubusercontent.com/mohmdnofal/aks-best-practices/master/stateful_workloads/zrs/mysql-statefulset.yaml


kubectl get svc -l app=mysql  
kubectl get pods -l app=mysql --watch


kubectl run mysql-client --image=mysql:5.7 -i --rm --restart=Never --\
  mysql -h mysql-0.mysql <<EOF
CREATE DATABASE zrstest;
CREATE TABLE zrstest.messages (message VARCHAR(250));
INSERT INTO zrstest.messages VALUES ('Hello from ZRS');
EOF


kubectl run mysql-client --image=mysql:5.7 -i -t --rm --restart=Never --\
  mysql -h mysql-read -e "SELECT * FROM zrstest.messages"


kubectl describe nodes | grep -i topology.kubernetes.io/zone

kubectl get nodes --output=custom-columns=NAME:.metadata.name,ZONE:".metadata.labels.topology\.kubernetes\.io/zone"

kubectl get pods -l app=mysql -o wide 

kubectl delete nodes aks-nodepool1-25938197-vmss000002

kubectl get pods -l app=mysql --watch -o wide

kubectl apply -f https://raw.githubusercontent.com/mohmdnofal/aks-best-practices/master/stateful_workloads/zrs/zrs-deployment.yaml

kubectl apply -f https://raw.githubusercontent.com/mohmdnofal/aks-best-practices/master/stateful_workloads/zrs/zrs-pvc.yaml


CSI V2
https://github.com/kubernetes-sigs/azuredisk-csi-driver/blob/master/deploy/example/failover/README.md

helm repo add azuredisk-csi-driver https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/charts

helm install azuredisk-csi-driver-v2 azuredisk-csi-driver/azuredisk-csi-driver \
  --namespace kube-system \
  --version v2.0.0-alpha.1 \
  --values=https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/charts/v2.0.0-alpha.1/azuredisk-csi-driver/side-by-side-values.yaml

cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: zrs-class
parameters:
  cachingmode: None
  skuName: StandardSSD_ZRS
  maxShares: "2"
provisioner: disk2.csi.azure.com
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: true
EOF