# Jaeger

https://blog.nobugware.com/post/2019/kubernetes_quick_development_setup_minikube_prometheus_grafana/
https://github.com/jaegertracing/jaeger-kubernetes/#production-setup

https://github.com/jaegertracing/jaeger/issues/1105
https://github.com/jaegertracing/jaeger/issues/1752

LOCATION="westeurope"
NODE_GROUP=MC_kub_ter_a_s_tracing9_tracing9_westeurope
KUBE_GROUP=kub_ter_a_s_tracing9
KUBE_NAME=tracing9
IP_NAME=traefik-ingress-pip
MY_ID=
CASSANDRA_GROUP=tracing
CASSANDRA_NAME=dztraces
CASSANDRA_HOST=$CASSANDRA_NAME.cassandra.cosmos.azure.com
CASSANDRA_PASSWORD=
CASSANDRA_PORT=10350
CASSANDRA_USERNAME=dztraces
CASSANDRA_KEYSPACE=traces


0. create cosmosdb and keyspace
```
az group create -n $CASSANDRA_GROUP -l $LOCATION

az cosmosdb create --name $CASSANDRA_NAME --resource-group $CASSANDRA_GROUP --capabilities EnableCassandra --enable-automatic-failover false --enable-multiple-write-locations false --enable-virtual-network false --kind GlobalDocumentDB 


CASSANDRA_PASSWORD=$(az cosmosdb keys list --name $CASSANDRA_NAME --resource-group $CASSANDRA_GROUP --type keys --query "primaryMasterKey" | tr -d '"')

az cosmosdb cassandra keyspace create --name $CASSANDRA_KEYSPACE --account-name $CASSANDRA_NAME --resource-group $CASSANDRA_GROUP

az cosmosdb cassandra keyspace list --account-name $CASSANDRA_NAME --resource-group $CASSANDRA_GROUP
```

0. deploy jaeger schema
```
docker pull jaegertracing/jaeger-query:latest
docker pull jaegertracing/jaeger-cassandra-schema:latest

docker run -d --restart always \
--name jaeger-query \
-e CASSANDRA_SERVERS=$CASSANDRA_HOST \
-e CASSANDRA_PORT=10350 \
-e CASSANDRA_PASSWORD=$CASSANDRA_PASSWORD \
-e CASSANDRA_USERNAME=$CASSANDRA_USERNAME  \
-e CASSANDRA_TLS=true \
-e CASSANDRA_KEYSPACE=$CASSANDRA_KEYSPACE \
-e CASSANDRA_CONNECTIONS_PER_HOST=1 \
-e CASSANDRA_TLS_VERIFY_HOST=false \
jaegertracing/jaeger-query:latest

docker run --rm -it -e CASSANDRA_USER=$CASSANDRA_USERNAME -e CASSANDRA_PASS=$CASSANDRA_PASSWORD -e CASSANDRA_HOST=$CASSANDRA_HOST -e SSL_VALIDATE=false -e SSL_VERSION=TLSv1_2 -e keyspace=$CASSANDRA_KEYSPACE -e replication=1 -e trace_ttl=172800 -e dependencies_ttl=0 --entrypoint bash jaegertracing/jaeger-cassandra-schema:latest -c 'sed  -e "s/--.*$//g" -e "/^\s*$/d" -e "s/\${keyspace}/${keyspace}/" -e "s/\${replication}/${replication}/" -e "s/\${trace_ttl}/${trace_ttl}/" -e "s/\${dependencies_ttl}/${dependencies_ttl}/" /cassandra-schema/v001.cql.tmpl > /cassandra-schema/v001.cql ; cqlsh ${CASSANDRA_HOST} 10350 -u ${CASSANDRA_USER} -p ${CASSANDRA_PASS} --ssl -f /cassandra-schema/v001.cql'
```

Output of schema creation

```
/cassandra-schema/v001.cql:11:SyntaxException: line 9:233 no viable alternative at input ') (... text,
    value_bool      boolean,
    value_long      bigint,
    value_double    double,
    value_binary    blob,
)...)
/cassandra-schema/v001.cql:15:SyntaxException: line 4:95 no viable alternative at input ') (...     bigint,
    fields  list<frozen<keyvalue>>,
)...)
/cassandra-schema/v001.cql:20:SyntaxException: line 5:124 no viable alternative at input ') (...ext,
    trace_id        blob,
    span_id         bigint,
)...)
/cassandra-schema/v001.cql:24:SyntaxException: line 4:113 no viable alternative at input ') (..._name    text,
    tags            list<frozen<keyvalue>>,
)...)
/cassandra-schema/v001.cql:48:InvalidRequest: Error from server: code=2200 [Invalid query] message="gc_grace_seconds value must be zero."
/cassandra-schema/v001.cql:61:InvalidRequest: Error from server: code=2200 [Invalid query] message="gc_grace_seconds value must be zero."
/cassandra-schema/v001.cql:75:InvalidRequest: Error from server: code=2200 [Invalid query] message="gc_grace_seconds value must be zero."
/cassandra-schema/v001.cql:91:InvalidRequest: Error from server: code=2200 [Invalid query] message="gc_grace_seconds value must be zero."
/cassandra-schema/v001.cql:107:InvalidRequest: Error from server: code=2200 [Invalid query] message="gc_grace_seconds value must be zero."
/cassandra-schema/v001.cql:125:InvalidRequest: Error from server: code=2200 [Invalid query] message="gc_grace_seconds value must be zero."
/cassandra-schema/v001.cql:144:InvalidRequest: Error from server: code=2200 [Invalid query] message="gc_grace_seconds value must be zero."
/cassandra-schema/v001.cql:149:SyntaxException: line 5:126 no viable alternative at input ') (...ext,
    child           text,
    call_count      bigint,
)...)
/cassandra-schema/v001.cql:161:InvalidRequest: Error from server: code=2200 [Invalid query] message="Unknown type traces.dependency"
/cassandra-schema/v001.cql:164:ConfigurationException: When using custom indexes, must have a class name and set to a supported class. Supported class names are ['CosmosDefaultIndex','AzureSearchIndex','CosmosClusteringIndex'] Got 'org.apache.cassandra.index.sasi.SASIIndex'
```

drop keyspace jaeger_v1_test;

CREATE KEYSPACE IF NOT EXISTS jaeger_v1_test WITH replication = {'class': 'SimpleStrategy', 'replication_factor': '1'};
CREATE TYPE IF NOT EXISTS jaeger_v1_test.keyvalue ("key" text,"value_type" text,"value_string" text,"value_bool" boolean,"value_long" bigint,"value_double" double,"value_binary" blob);
CREATE TYPE IF NOT EXISTS jaeger_v1_test.log ("ts" bigint,"fields" list<frozen>);
CREATE TYPE IF NOT EXISTS jaeger_v1_test.span_ref ("ref_type" text,"trace_id" blob,"span_id" bigint);
CREATE TYPE IF NOT EXISTS jaeger_v1_test.process ("service_name" text,"tags" list<frozen>);

CREATE TABLE IF NOT EXISTS jaeger_v1_test.traces ("trace_id" blob,"span_id" bigint,"span_hash" bigint,"parent_id" bigint,"operation_name" text,"flags" int,"start_time" bigint,"duration" bigint,"tags" list<frozen>,"logs" list<frozen>,"refs" list<frozen<span_ref>>,"process" frozen,PRIMARY KEY (trace_id, span_id, span_hash)) WITH compaction = {'compaction_window_size': '1','compaction_window_unit': 'HOURS','class': 'org.apache.cassandra.db.compaction.TimeWindowCompactionStrategy'} AND dclocal_read_repair_chance = 0.0 AND default_time_to_live = 172800 AND speculative_retry = 'NONE' AND gc_grace_seconds = 0;

CREATE TABLE IF NOT EXISTS jaeger_v1_test.service_names ("service_name" text,PRIMARY KEY ("service_name")) WITH compaction = {'min_threshold': '4','max_threshold': '32','class': 'org.apache.cassandra.db.compaction.SizeTieredCompactionStrategy'} AND dclocal_read_repair_chance = 0.0 AND default_time_to_live = 172800 AND speculative_retry = 'NONE' AND gc_grace_seconds = 0;

CREATE TABLE IF NOT EXISTS jaeger_v1_test.operation_names ("service_name" text,"operation_name" text,PRIMARY KEY (("service_name"), "operation_name")) WITH compaction = {'min_threshold': '4','max_threshold': '32','class': 'org.apache.cassandra.db.compaction.SizeTieredCompactionStrategy'} AND dclocal_read_repair_chance = 0.0 AND default_time_to_live = 172800 AND speculative_retry = 'NONE' AND gc_grace_seconds = 0;

CREATE TABLE IF NOT EXISTS jaeger_v1_test.service_operation_index ("service_name" text,"operation_name" text,"start_time" bigint,"trace_id" blob,PRIMARY KEY (("service_name", "operation_name"), "start_time")) WITH CLUSTERING ORDER BY (start_time DESC) AND compaction = {'compaction_window_size': '1','compaction_window_unit': 'HOURS','class': 'org.apache.cassandra.db.compaction.TimeWindowCompactionStrategy'} AND dclocal_read_repair_chance = 0.0 AND default_time_to_live = 172800 AND speculative_retry = 'NONE' AND gc_grace_seconds = 0;

CREATE TABLE IF NOT EXISTS jaeger_v1_test.service_name_index ("service_name" text,"bucket" int,"start_time" bigint,"trace_id" blob,PRIMARY KEY (("service_name", "bucket"), "start_time")) WITH CLUSTERING ORDER BY (start_time DESC) AND compaction = {'compaction_window_size': '1','compaction_window_unit': 'HOURS','class': 'org.apache.cassandra.db.compaction.TimeWindowCompactionStrategy'} AND dclocal_read_repair_chance = 0.0 AND default_time_to_live = 172800 AND speculative_retry = 'NONE' AND gc_grace_seconds = 0;

CREATE TABLE IF NOT EXISTS jaeger_v1_test.duration_index ("service_name" text,"operation_name" text,"bucket" timestamp, "duration" bigint,"start_time" bigint,"trace_id" blob, PRIMARY KEY ((service_name, operation_name, bucket), "duration", start_time, trace_id)) WITH CLUSTERING ORDER BY ("duration" DESC, start_time DESC, trace_id DESC) AND compaction = {'compaction_window_size': '1', 'compaction_window_unit': 'HOURS', 'class': 'org.apache.cassandra.db.compaction.TimeWindowCompactionStrategy'} AND dclocal_read_repair_chance = 0.0 AND default_time_to_live = 172800 AND speculative_retry = 'NONE' AND gc_grace_seconds = 0;

CREATE TABLE IF NOT EXISTS jaeger_v1_test.tag_index (service_name text,tag_key text,tag_value text,start_time bigint,trace_id blob,span_id bigint,PRIMARY KEY ((service_name, tag_key, tag_value), start_time, trace_id, span_id)) WITH CLUSTERING ORDER BY (start_time DESC, trace_id DESC, span_id DESC) AND compaction = {'compaction_window_size': '1','compaction_window_unit': 'HOURS','class': 'org.apache.cassandra.db.compaction.TimeWindowCompactionStrategy'} AND dclocal_read_repair_chance = 0.0 AND default_time_to_live = 172800 AND speculative_retry = 'NONE' AND gc_grace_seconds = 0;

CREATE TYPE IF NOT EXISTS jaeger_v1_test.dependency ("parent" text,"child" text,"call_count" bigint);

CREATE TABLE IF NOT EXISTS jaeger_v1_test.dependencies (ts timestamp,ts_index timestamp,dependencies list<frozen>,PRIMARY KEY (ts)) WITH compaction = {'min_threshold': '4','max_threshold': '32','class': 'org.apache.cassandra.db.compaction.SizeTieredCompactionStrategy'} AND default_time_to_live = 0;

CREATE CUSTOM INDEX ON jaeger_v1_test.dependencies (ts_index) USING 'org.apache.cassandra.index.sasi.SASIIndex' WITH OPTIONS = {'mode': 'SPARSE'};


DNS=$(az network public-ip show --resource-group $NODE_GROUP --name $IP_NAME --query dnsSettings.fqdn --output tsv)
IP=$(az network public-ip show --resource-group $NODE_GROUP --name $IP_NAME --query ipAddress --output tsv)



helm upgrade traefikingress stable/traefik --install --namespace kube-system --set dashboard.enabled=true,dashboard.domain=dashboard.localhost,rbac.enabled=true,loadBalancerIP=$IP,externalTrafficPolicy=Local,replicas=1,ssl.enabled=true,ssl.permanentRedirect=true,ssl.insecureSkipVerify=true,acme.enabled=true,acme.challengeType=http-01,acme.email=$MY_ID,acme.staging=false


helm upgrade grafana stable/grafana --install --set ingress.enabled=true --set ingress.hosts\[0\]=grafana.localhost --set persistence.enabled=true --set persistence.size=100Mi --namespace grafana

helm upgrade prometheus stable/prometheus --install --set server.ingress.enabled=true --set server.ingress.hosts\[0\]=prometheus.localhost --set alertmanager.enabled=false --set kubeStateMetrics.enabled=false --set nodeExporter.enabled=false --set server.persistentVolume.enabled=true --set server.persistentVolume.size=1Gi --set pushgateway.enabled=false --namespaces prometheus


jaeger_v1_dc1

helm template incubator/jaeger --name myjaeger --set provisionDataStore.cassandra=false --set storage.cassandra.host=$CASSANDRA_HOST --set storage.cassandra.port=$CASSANDRA_PORT --set storage.cassandra.user=$CASSANDRA_USERNAME --set storage.cassandra.password=$CASSANDRA_PASSWORD --set hotrod.enabled=true > jaeger.yaml

helm upgrade myjaeger incubator/jaeger --install --set provisionDataStore.cassandra=false --set storage.cassandra.host=$CASSANDRA_HOST --set storage.cassandra.port=$CASSANDRA_PORT --set storage.cassandra.user=$CASSANDRA_USERNAME --set storage.cassandra.password=$CASSANDRA_PASSWORD

helm install incubator/jaeger --name myrel --set cassandra.config.max_heap_size=512M --set cassandra.config.heap_new_size=256M --set cassandra.resources.requests.memory=512Mi --set cassandra.resources.requests.cpu=0.4 --set cassandra.resources.limits.memory=1024Mi --set cassandra.resources.limits.cpu=0.4 --namespace jaegerkube


kubectl apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-kubernetes/master/all-in-one/jaeger-all-in-one-template.yml


kubectl -n default port-forward $(kubectl get pod -l app.kubernetes.io/component=hotrod -o jsonpath='{.items[0].metadata.name}') 8081:8080 

https://github.com/helm/charts/tree/master/stable/traefik

helm upgrade traefikingress stable/traefik --install --namespace kube-system --set dashboard.enabled=true,dashboard.domain=dashboard.localhost,rbac.enabled=true,loadBalancerIP=$IP,externalTrafficPolicy=Local,replicas=1,ssl.enabled=true,ssl.permanentRedirect=true,ssl.insecureSkipVerify=true,acme.enabled=true,acme.challengeType=http-01,acme.email=$MY_ID,acme.staging=false,tracing.enabled=true,tracing.backend=jaeger,tracing.jaeger.localAgentHostPort=myjaeger-agent:6831,tracing.serviceName=jaeger,tracing.jaeger.samplingServerUrl=myjaeger-agent:5778/sampling

tracing9.westeurope.cloudapp.azure.com
13.80.129.114

driver=T769745C

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: hotrod
  annotations:
    kubernetes.io/ingress.class: traefik
    ingress.kubernetes.io/whitelist-x-forwarded-for: "true"
    traefik.ingress.kubernetes.io/redirect-permanent: "false"
    traefik.ingress.kubernetes.io/preserve-host: "true"
spec:
  rules:
  - host: $DNS
    http:
      paths:
      - path: /
        backend:
          serviceName: myjaeger-hotrod
          servicePort: 80
EOF
