# Azure DNS
https://github.com/kubernetes-incubator/external-dns/blob/master/docs/tutorials/azure.md
https://github.com/helm/charts/tree/master/stable/external-dns

```

az network dns zone create -g $KUBE_GROUP -n example.com
```


https://stackoverflow.com/questions/53290626/can-aks-be-configured-to-work-with-an-azure-private-dns-zone

publishInternalServices=true