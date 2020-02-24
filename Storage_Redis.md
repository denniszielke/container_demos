# Redis install

helm upgrade redis stable/redis --install --set password=secretpassword --set cluster.enabled=false --namespace=redis

REDIS_HOST=redis-master:6379
REDIS_PASSWORD=secretpassword

kubectl run --namespace redis redis-client --restart='Never' \
    --env REDIS_PASSWORD=$REDIS_PASSWORD \
   --image docker.io/bitnami/redis:5.0.7-debian-10-r0 -- bash

Connect using the Redis CLI:

redis-cli -h redis-master -a $REDIS_PASSWORD
