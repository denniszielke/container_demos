#

kubectl create ns jenkins
helm install my-jenkins stable/jenkins -n jenkins


printf $(kubectl get secret --namespace jenkins my-jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo

export POD_NAME=$(kubectl get pods --namespace jenkins -l "app.kubernetes.io/component=jenkins-master" -l "app.kubernetes.io/instance=my-jenkins" -o jsonpath="{.items[0].metadata.name}")
  echo http://127.0.0.1:8080
  kubectl --namespace jenkins port-forward $POD_NAME 8080:8080