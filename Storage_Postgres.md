# Postgres inside the cluster
https://engineering.bitnami.com/articles/create-a-production-ready-postgresql-cluster-bitnami-kubernetes-and-helm.html

cd /Users/dennis/demos/postgres

wget https://raw.githubusercontent.com/helm/charts/master/stable/postgresql/values-production.yaml


ROOT_PASSWORD=
REPLICATION_PASSWORD=

## install using azure disk
helm install --name postgres-disk stable/postgresql -f values-production-disk.yaml
helm install --name postgres-disk stable/postgresql -f values-production-disk.yaml --set postgresqlPassword=ROOT_PASSWORD --set replication.password=REPLICATION_PASSWORD --set postgresqlDatabase=mydatabase --namespace=pdisk


install metrics
kubectl apply -f logging/postgres-amz-config.yaml 

https://www.peterbe.com/plog/how-i-performance-test-postgresql-locally-on-macos

azure files mount options
https://github.com/andyzhangx/Demo/blob/master/linux/azurefile/azurefile-mountoptions.md

cat <<EOF | kubectl apply -f -
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: azurefile
provisioner: kubernetes.io/azure-file
mountOptions:
  - dir_mode=0777
  - file_mode=0777
  - uid=1000
  - gid=1000
  - mfsymlinks
  - nobrl
  - cache=none
parameters:
  skuName: Standard_LRS
  location: $LOCATION
  storageAccount: $STORAGE_ACCOUNT
EOF

kubectl run my-postgresql-client --tty -i --image bitnami/postgresql --env="ALLOW_EMPTY_PASSWORD=yes"

kubectl run my-postgresql-client --rm --tty -i --image bitnami/postgresql --env="PGPASSWORD=$DB_PASSWORD" --command -- psql --host $DB_HOST -U $DB_USER

postgres=# SELECT client_addr, state FROM pg_stat_replication;

# create and insert data on the master
```
kubectl run my-release-postgresql-client --rm --tty -i --image bitnami/postgresql --env="PGPASSWORD=ROOT_PASSWORD" --command -- psql --host my-release-postgresql -U postgres
postgres=# CREATE TABLE test (id int not null, val text not null);
postgres=# INSERT INTO test VALUES (1, 'foo');
postgres=# INSERT INTO test VALUES (2, 'bar');
```
# connect to the slave and verify data
```
kubectl exec -it my-release-postgresql-slave-0 -- bash
bash> export PGPASSWORD=$DB_PASSWORD
bash> psql --host $DB_HOST -U $DB_USER
postgres=# SELECT * FROM test;


DB_HOST=dzdemosql.postgres.database.azure.com
DB_PASSWORD=MC_aksv2_aksv2_westus2
DB_USER=dennis@dzdemosql

psql -h $DB_HOST master $DB_USER
```