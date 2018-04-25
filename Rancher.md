
1. Create ubuntu box and install docker
2. Create mysql database in azure

```
RANCHER_RG=ubuntutools
RANCHER_MYSQL_ADMIN=ranchsa
RANCHER_MYSQL_ADMINPW=
RANCHER_MYSQL_NAME=rancherconfig
RANCHER_MYSQL_SRV=rancherdb

az mysql server create -g $RANCHER_RG -n $RANCHER_MYSQL_SRV --location northeurope --admin-user $RANCHER_MYSQL_ADMIN --admin-password $RANCHER_MYSQL_ADMINPW --sku-name B_Gen4_1 --version 5.7

az mysql server firewall-rule create -g $RANCHER_RG -s $RANCHER_MYSQL_SRV --name "AllowAllWindowsAzureIps" --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0

az mysql server update -g $RANCHER_RG -n $RANCHER_MYSQL_SRV --ssl-enforcement Disabled

az mysql db create -g $RANCHER_RG -s $RANCHER_MYSQL_SRV -n $RANCHER_MYSQL_NAME --charset "utf8" --collation "utf8_general_ci"

```
3. Run rancher with mysql database
```
docker run -e CATTLE_DB_CATTLE_GO_PARAMS="allowNativePasswords=true" -d --restart=unless-stopped -p 8080:8080 rancher/server --db-host $(echo $RANCHER_MYSQL_SRV).mysql.database.azure.com --db-port 3306 --db-user $(echo $RANCHER_MYSQL_ADMIN)@$(echo $RANCHER_MYSQL_SRV) --db-pass $RANCHER_MYSQL_ADMINPW --db-name $RANCHER_MYSQL_NAME --db-strict-enforcing

```

sudo mkdir -p /storage/docker/mysql-datadir
docker run -d -v /storage/docker/mysql-datadir:/var/lib/mysql --restart=unless-stopped -p 8080:8080 rancher/server

sudo mkdir -p /storage/docker/mysql-datadir2
docker run -d -v /storage/docker/mysql-datadir2:/var/lib/mysql --restart=unless-stopped -p 8080:8080 -p 443:443 rancher/server:preview

