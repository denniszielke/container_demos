


kubectl -n linkerd logs deployment/flagger -f | jq .msg

kubectl -n istio-system logs deployment/flagger -f | jq .msg


kubectl -n test set image deployment/podinfo podinfod=quay.io/stefanprodan/podinfo:1.7.1