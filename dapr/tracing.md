# Tracing with Azure Monitor


## setting up local forwarder
https://docs.microsoft.com/en-us/azure/azure-monitor/app/opencensus-local-forwarder#linux


# Tracing with Zipkin
https://github.com/dapr/docs/blob/master/howto/diagnose-with-tracing/zipkin.md


```
kubectl run zipkin --image openzipkin/zipkin --port 9411
kubectl expose deploy zipkin --type ClusterIP --port 9411
kubectl apply -f zipkin.yaml
kubectl port-forward svc/zipkin 9411:9411
