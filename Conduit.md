# Conduit
https://conduit.io/

curl https://run.conduit.io/install | bash

export PATH="$PATH:/Users/dennis/.linkerd2/bin"
export PATH=$PATH:$HOME/.linkerd2/bin
Zsh
export PATH="$HOME/.linkerd2/bin:$PATH"


helm install multicalchart --name=calculator --set frontendReplicaCount=1 --set backendReplicaCount=1 --set image.frontendTag=latest --set image.backendTag=latest --set useAppInsights=yes --namespace $APP_NAME

helm upgrade --set backendReplicaCount=4 --set frontendReplicaCount=4 calculator multicalchart 

kubectl get po,deployment,rc,rs,ds,no,job -n calculator -o yaml > calculator.yaml

linkerd inject calculator.yaml | kubectl apply -f - 

kubectl get pod --all-namespaces

linkerd dashboard

kubectl --namespace monitoring port-forward $(kubectl get pod --namespace monitoring -l app=kube-prometheus-grafana -o template --template "{{(index .items 0).metadata.name}}") 3000:3000