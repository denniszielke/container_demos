https://github.com/weaveworks/kured#installation
https://docs.microsoft.com/en-us/azure/aks/node-updates-kured


let ContainerIdList = KubePodInventory
| where TimeGenerated > ago(1d)
| where ContainerName contains 'check-reboot'
| distinct ContainerID;
ContainerLog
| where TimeGenerated > ago(1d)
| where ContainerID in (ContainerIdList)
| project ClusterName, LogEntry, TimeGenerated, Computer 
| where LogEntry startswith "check-reboot status" and LogEntry contains "reboot required"
| render table


let ContainerIdList = KubePodInventory
| where TimeGenerated > ago(1h)
| where ContainerName contains 'check-reboot'
| distinct ContainerID;
ContainerLog
| where TimeGenerated > ago(1d)
| where ContainerID in (ContainerIdList)
| project LogEntry, TimeGenerated, Computer
| where LogEntry startswith "check-reboot status" and LogEntry contains "reboot required"
| distinct Computer
| join kind= innerunique (KubeNodeInventory) on Computer
| project ClusterName, Computer 
| render table


let ContainerIdList = KubePodInventory
| where TimeGenerated > ago(1h) | where ContainerName contains 'check-reboot' | distinct ContainerID;
ContainerLog | where TimeGenerated > ago(1d) | where ContainerID in (ContainerIdList)
| project LogEntry, TimeGenerated, Computer
| where LogEntry startswith "check-reboot status" and LogEntry contains "reboot required"
| join kind= innerunique (KubeNodeInventory | where TimeGenerated > ago(1h) 
| distinct Computer, ClusterName ) on Computer
| project ClusterName, Computer 
| render table

let ContainerIdList = KubePodInventory
| where TimeGenerated > ago(1h)
| where ContainerName contains 'check-reboot'
| distinct ContainerName;
ContainerLog
| where TimeGenerated > ago(1h)
| where Name in (ContainerIdList)
| project LogEntry, TimeGenerated, Computer
| where LogEntry startswith "check-reboot status" and LogEntry contains "reboot required"
| join kind= innerunique
(
    KubeNodeInventory
    | where TimeGenerated > ago(1d)
    | distinct Computer, ClusterName
)
on Computer
| project ClusterName, Computer
| render table

{ "text":"There are #searchresultcount worker nodes needing a reboot", "IncludeSearchResults":true }

{"text":"There are 1 worker nodes needing a reboot","IncludeSearchResults":true,"SearchResult":
        {
		"tables":[
                    {"name":"PrimaryResult","columns":
                        [
				        {"name":"$table","type":"string"},
					    {"name":"Id","type":"string"},
					    {"name":"TimeGenerated","type":"datetime"}
                        ],
					"rows":
                        [
						    ["Fabrikam","33446677a","2018-02-02T15:03:12.18Z"],
                            ["Contoso","33445566b","2018-02-02T15:16:53.932Z"]
                        ]
                    }
                ]
        }
    }


helm install --name prometheus stable/prometheus --namespace prometheus

kubectl --namespace prometheus port-forward $(kubectl get pod --namespace prometheus -l prometheus=kube-prometheus -l app=prometheus -o template --template "{{(index .items 0).metadata.name}}") 9090:9090

helm install --name grafana stable/grafana --namespace grafana
kubectl --namespace grafana port-forward $(kubectl get pod --namespace grafana -l app=kube-prometheus-grafana -o template --template "{{(index .items 0).metadata.name}}") 3000:3000

kubectl apply -f https://github.com/weaveworks/kured/releases/download/1.1.0/kured-1.1.0.yaml
