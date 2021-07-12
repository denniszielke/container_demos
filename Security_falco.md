# Falco

## Install
https://github.com/falcosecurity/charts/tree/master/falco#introduction

```
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
kubectl create namespace falco
helm upgrade falco falcosecurity/falco --set fakeEventGenerator.enabled=true --set falcosidekick.enabled=true --set falcosidekick.webui.enabled=true --namespace falco --install

kubectl -n falco port-forward svc/falco-falcosidekick 2801

curl -s http://localhost:2801/ping
kubectl -n falco logs deployment/falco-falcosidekick

kubectl port-forward svc/falco-falcosidekick-ui -n falco 2802

http://localhost:2802/ui/#/

kubectl run nginx --image=nginx

kubectl exec -it nginx -- /bin/sh   

etc/shadow

```


## Test falco

```

kubectl run shell --restart=Never -it --image krisnova/hack:latest \
  --rm --attach \
  --overrides \
        '{
          "spec":{
            "hostPID": true,
            "containers":[{
              "name":"scary",
              "image": "krisnova/hack:latest",
	      "imagePullPolicy": "Always",
              "stdin": true,
              "tty": true,
              "command":["/bin/bash"],
	      "nodeSelector":{
		"dedicated":"master" 
	      },
              "securityContext":{
                "privileged":true
              }
            }]
          }
        }'


```



