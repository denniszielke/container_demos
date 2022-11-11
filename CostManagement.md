# Kusto query


```
let queryStartTime = ago(21600000ms);
let queryEndTime = now();
let tollerance = 1;
let tonullneg1 = (arg0: real) { iff(arg0 == -1., real(null), arg0) };
let NODE_LIMITS = Perf
    | where TimeGenerated > ago(10m)
    | where CounterName == "memoryAllocatableBytes" or CounterName == "cpuAllocatableNanoCores"
    | as T
    | where CounterName == "memoryAllocatableBytes"
    | summarize memoryAllocatableBytes = any(CounterValue) by Computer
    | join (
        T 
        | where CounterName == "cpuAllocatableNanoCores" 
        | summarize cpuAllocatableNanoCores = any(CounterValue) by Computer
        )
        on Computer
    | project memoryAllocatableBytes, cpuAllocatableNanoCores, Computer;
//
let perfdata = materialize(Perf
    | project
        TimeGenerated,
        ObjectName,
        InstanceName,
        _ResourceId,
        CounterName,
        CounterValue,
        Computer
    | where TimeGenerated >= queryStartTime and TimeGenerated <= queryEndTime
    | where ObjectName == 'K8SContainer'
    | where ((CounterName == 'memoryLimitBytes' or CounterName == 'memoryRequestBytes' or CounterName == 'cpuLimitNanoCores' or CounterName == 'cpuRequestNanoCores') and TimeGenerated > (queryEndTime - 1h))
        or CounterName == 'memoryRssBytes'
        or CounterName == 'cpuUsageNanoCores'
    | extend ClusterName = tostring(iff(InstanceName contains '/providers/microsoft.containerservice/managedclusters', split(InstanceName, '/')[8], iff(InstanceName contains '/subscriptions/', split(InstanceName, '/')[4], split(InstanceName, '/')[0])))
    | extend PodUid = tostring(iff(InstanceName contains '/providers/microsoft.containerservice/managedclusters', split(InstanceName, '/')[9], iff(InstanceName contains '/subscriptions/', split(InstanceName, '/')[5], split(InstanceName, '/')[1])))
    | extend ContainerName = tostring(iff(InstanceName contains '/providers/microsoft.containerservice/managedclusters', split(InstanceName, '/')[10], iff(InstanceName contains '/subscriptions/', split(InstanceName, '/')[6], split(InstanceName, '/')[2])))
    | where isnotempty(PodUid)
    | extend ResourceName = strcat(ClusterName, '/', PodUid, '/', ContainerName)
    | join kind = inner NODE_LIMITS on Computer
    | join kind = inner (
        KubePodInventory
        | where TimeGenerated >= queryEndTime - 10m and TimeGenerated <= queryEndTime
        | summarize any(Name, Namespace, ControllerName, ControllerKind, ClusterId) by PodUid
        | project
            PodName = any_Name,
            ControllerNameMaybe = any_ControllerName,
            ControllerKindMaybe = any_ControllerKind,
            Namespace = any_Namespace,
            PodUid
        )
        on PodUid
    | project-away PodUid1
    // not all pods have controllers
    | extend ControllerName = iff(isnull(ControllerNameMaybe) or ControllerNameMaybe == "", strcat(PodName, " (dummy value)"), ControllerNameMaybe)
    | extend ControllerKind = iff(isnull(ControllerKindMaybe) or ControllerKindMaybe == "", "single pod (dummy value)", ControllerKindMaybe)
    | project-away ControllerKindMaybe, ControllerNameMaybe
    //
    | extend hasMemLimit = iff(CounterValue == memoryAllocatableBytes, -1., CounterValue) // no limit check
    | extend hasMemRequest = iff(CounterValue == memoryAllocatableBytes, -1., CounterValue) // no request check
    | extend hasCpuRequest = iff(CounterValue == cpuAllocatableNanoCores, -1., CounterValue) // no request check
    | extend hasCpuLimit = iff(CounterValue == cpuAllocatableNanoCores, -1., CounterValue) // no limit check
    | summarize measurement_counts = count(), _max = max(CounterValue), p90=percentile(CounterValue, 90), p99=percentile(CounterValue, 99), measurementEndTime = max(TimeGenerated), measurementStartTime = min(TimeGenerated),
        hasMemLimit=min(hasMemLimit), hasMemRequest=min(hasMemRequest), hasCpuRequest=min(hasCpuRequest), hasCpuLimit=min(hasCpuLimit)
        by
        ClusterName,
        Namespace,
        ControllerName,
        ControllerKind,
        ContainerName,
        CounterName
    );
//
perfdata
| where CounterName == 'memoryLimitBytes'
| project
    memLimitCount = measurement_counts,
    memLimitVal = tonullneg1(hasMemLimit),
    ClusterName,
    Namespace,
    ControllerName,
    ControllerKind,
    ContainerName
//
| join kind = fullouter (
    perfdata
    | where CounterName == 'memoryRequestBytes'
    | project
        memRequestCount = measurement_counts,
        memRequestVal = tonullneg1(hasMemRequest),
        ClusterName,
        Namespace,
        ControllerName,
        ControllerKind,
        ContainerName
    )
    on ClusterName, Namespace, ControllerName, ControllerKind, ContainerName
| project-away ClusterName1, Namespace1, ControllerName1, ControllerKind1, ContainerName1
//
| join kind = fullouter (
    perfdata
    | where CounterName == 'memoryRssBytes'
    | project
        mem_measurement_counts = measurement_counts,
        mem_max = _max,
        mem_p90=p90,
        mem_p99=p99,
        measurementEndTime = measurementEndTime,
        measurementStartTime = measurementStartTime,
        ClusterName,
        Namespace,
        ControllerName,
        ControllerKind,
        ContainerName
    )
    on ClusterName, Namespace, ControllerName, ControllerKind, ContainerName
| project-away ClusterName1, Namespace1, ControllerName1, ControllerKind1, ContainerName1
//
| join kind = fullouter (
    perfdata
    | where CounterName == 'cpuRequestNanoCores'
    | project
        cpuRequestCount = measurement_counts,
        cpuRequestVal = tonullneg1(hasCpuRequest),
        ClusterName,
        Namespace,
        ControllerName,
        ControllerKind,
        ContainerName
    )
    on ClusterName, Namespace, ControllerName, ControllerKind, ContainerName
| project-away ClusterName1, Namespace1, ControllerName1, ControllerKind1, ContainerName1
//
| join kind = fullouter (
    perfdata
    | where CounterName == 'cpuLimitNanoCores'
    | project
        cpuLimitCount = measurement_counts,
        cpuLimitVal = tonullneg1(hasCpuLimit),
        ClusterName,
        Namespace,
        ControllerName,
        ControllerKind,
        ContainerName
    )
    on ClusterName, Namespace, ControllerName, ControllerKind, ContainerName
| project-away ClusterName1, Namespace1, ControllerName1, ControllerKind1, ContainerName1
//
| join kind = fullouter (
    perfdata
    | where CounterName == 'cpuUsageNanoCores'
    | project
        cpu_measurement_counts = measurement_counts,
        cpu_max = _max,
        cpu_p90=p90,
        cpu_p99=p99,
        ClusterName,
        Namespace,
        ControllerName,
        ControllerKind,
        ContainerName
    )
    on ClusterName, Namespace, ControllerName, ControllerKind, ContainerName
| project-away ClusterName1, Namespace1, ControllerName1, ControllerKind1, ContainerName1
//
| where cpuLimitCount > 2
    and memLimitCount > 2
    and mem_measurement_counts >= 1
    and cpu_measurement_counts >= 1 // ensure there are enough measurements
| extend suggestedMemRequest = mem_p99 * 1.5
| extend suggestedMemLimit = mem_p99 * 3
| extend suggestedCpuRequest = cpu_p99 * 1.5 + 5
| extend suggestedCpuLimit = cpu_p99 * 3 + 5
| extend diffMemRequest = abs(suggestedMemRequest - memRequestVal) / suggestedMemRequest
| extend diffMemLimit = abs(suggestedMemLimit - memLimitVal) / suggestedMemLimit
| extend diffCpuRequest = abs(suggestedCpuRequest - cpuRequestVal) / suggestedCpuRequest
| extend diffCpuLimit = abs(suggestedCpuLimit - cpuLimitVal) / suggestedCpuLimit
| extend distAboveTolerance = max_of(diffMemRequest / tollerance, diffMemLimit / tollerance, diffCpuRequest / tollerance, diffCpuLimit / tollerance)
| extend hasnulls = (isnull(cpuRequestVal) or isnull(cpuLimitVal) or isnull(memRequestVal) or isnull(memLimitVal))
| extend colorKey = iff(hasnulls, real(null), log10(distAboveTolerance))
| where (not(hasnulls) and ("all" == "set" or "all" == "all")) or (hasnulls and ("all" == "notset" or "all" == "all"))
| extend containerKey = base64_encode_tostring(strcat(ClusterName, "/", Namespace, "/", ControllerKind, "/", ControllerName, "/", ContainerName))
| project
    ClusterName,
    Namespace,
    ControllerName,
    ControllerKind,
    ContainerName,
    memRequestVal,
    memLimitVal,
    mem_p90,
    mem_p99,
    mem_max,
    cpuRequestVal,
    cpuLimitVal,
    cpu_p90,
    cpu_p99,
    cpu_max,
    suggestedMemRequest,
    suggestedMemLimit,
    suggestedCpuRequest,
    suggestedCpuLimit,
    distAboveTolerance,
    colorKey,
    containerKey
//
| extend
    memRequestVal_final = iff(isnull(memRequestVal), -1.0, memRequestVal),
    memLimitVal_final = iff(isnull(memLimitVal), -1.0, memLimitVal),
    cpuRequestVal_final = iff(isnull(cpuRequestVal), -1.0, cpuRequestVal),
    cpuLimitVal_final = iff(isnull(cpuLimitVal), -1.0, cpuLimitVal)
| project-away memRequestVal, memLimitVal, cpuRequestVal, cpuLimitVal
| project-rename
    memRequestVal = memRequestVal_final,
    memLimitVal = memLimitVal_final,
    cpuRequestVal = cpuRequestVal_final,
    cpuLimitVal = cpuLimitVal_final
```