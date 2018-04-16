Now connect to any of the deployment pods -
kubectl exec -ti test-keyvault-7d94566cdb-7wmx9 -c test-app /bin/sh
and now just view the secrets with

cat /secrets/secrets/<secret_name>
cat /secrets/certs/<certificate_name>
cat /secrets/keys/<key_name>