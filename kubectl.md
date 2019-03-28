
More: https://kubernetes.io/docs/tasks/access-application-cluster/list-all-running-container-images/

For each pod, list whether it containers run on a read-only root filesystem or not:

```
kubectl get pods --all-namespaces -o go-template --template='{{range .items}}{{.metadata.name}}{{"\n"}}{{range .spec.containers}}    read-only: {{if .securityContext.readOnlyRootFilesystem}}{{printf "\033[32m%t\033[0m" .securityContext.readOnlyRootFilesystem}} {{else}}{{printf "\033[91m%s\033[0m" "false"}}{{end}} ({{.name}}){{"\n"}}{{end}}{{"\n"}}{{end}}'
```

Get pod count per node
```
kubectl get po -o json --all-namespaces | jq '.items | group_by(.spec.nodeName) | map({"nodeName": .[0].spec.nodeName, "count": length}) | sort_by(.count)'
```

Get nodes internal ips
```
kubectl get no -o json | jq -r '.items[].status.addresses[] | select(.type=="InternalIP") | .address'
```


get pvc sizes
```
kubectl get pv -o json | jq -r '.items | sort_by(.spec.capacity.storage)[]|[.metadata.name,.spec.capacity.storage]| @tsv'
```

get nodes memory capacizy
```
kubectl get no -o json | jq -r '.items | sort_by(.status.capacity.memory)[]|[.metadata.name,.status.capacity.memory]| @tsv'
```


