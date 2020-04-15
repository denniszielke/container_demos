## redis
https://github.com/dapr/docs/blob/master/concepts/components/redis.md#creating-a-redis-store
https://github.com/dapr/docs/blob/master/concepts/components/redis.md#creating-a-redis-cache-in-your-kubernetes-cluster-using-helm

kubectl create namespace redis
helm upgrade redis stable/redis --install --set password=secretpassword --namespace redis
helm delete redis

kubectl get secret --namespace default redis -o jsonpath="{.data.redis-password}" | base64 --decode 

cat <<EOF | kubectl apply -f -
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: redispubsub
spec:
  type: pubsub.redis
  metadata:
  - name: redisHost
    value: redis-master:6379
  - name: redisPassword
    value: secretpassword
EOF

cat <<EOF | kubectl apply -f -
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: statestore
spec:
  type: state.redis
  metadata:
  - name: redisHost
    value: redis-master:6379
  - name: redisPassword
    value: secretpassword
EOF

REDIS_HOST=.redis.cache.windows.net:6379
REDIS_PASSWORD=

cat <<EOF | kubectl apply -f -
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: statestore
spec:
  type: state.redis
  metadata:
  - name: redisHost
    value: $REDIS_HOST
  - name: redisPassword
    value: $REDIS_PASSWORD
EOF