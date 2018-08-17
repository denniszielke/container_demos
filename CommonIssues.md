# Common issues

## New version of azure cli does not work with az aks browse or aks get credentials

'ManagedCluster' object has no attribute 'properties'

Downgrade azure cli to working version

```
WORKING_VERSION=2.0.23-1
sudo apt-get install azure-cli=$WORKING_VERSION
```

## NIC in failed state
reset nic via cli
```
az network nic update -g MC_* -n aks-nodepool1-*-nic-0
```

## Find out source ip

```
curl ipinfo.io/ip
```