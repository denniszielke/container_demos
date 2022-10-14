

ndzauthd2.northeurope.cloudapp.azure.com


AD_APP_NAME="ndzauthd2-easy-auth-proxy"

APP_HOSTNAME="ndzauthd2.northeurope.cloudapp.azure.com"
HOMEPAGE=https://$APP_HOSTNAME
REPLY_URLS=https://$APP_HOSTNAME/easyauth/signin-oidc

https://ndzauthd2.northeurope.cloudapp.azure.com/easyauth/signin-oidc

cat << EOF > manifest.json
[
    {
      "resourceAccess" : [
          {
            "id" : "e1fe6dd8-ba31-4d61-89e7-88639da4683d",
            "type" : "Scope"
          }
      ],
      "resourceAppId" : "00000003-0000-0000-c000-000000000000"
    }
]
EOF


cat manifest.json

CLIENT_ID=$(az ad app create --display-name $AD_APP_NAME --identifier-uris $REPLY_URLS --app-roles @manifest.json -o json | jq -r '.id')
echo $CLIENT_ID

OBJECT_ID=$(az ad app show --id $CLIENT_ID -o json | jq '.objectId' -r)
echo $OBJECT_ID

az ad app update --id $OBJECT_ID --set oauth2Permissions[0].isEnabled=false
az ad app update --id $OBJECT_ID --set oauth2Permissions=[]


# The newly registered app does not have a password.  Use "az ad app credential reset" to add password and save to a variable.
CLIENT_SECRET=$(az ad app credential reset --id $CLIENT_ID -o json | jq '.password' -r)
echo $CLIENT_SECRET

# Get your Azure AD tenant ID and save to variable
AZURE_TENANT_ID=$(az account show -o json | jq '.tenantId' -r)
echo $AZURE_TENANT_ID


helm install --set azureAd.tenantId=$AZURE_TENANT_ID --set azureAd.clientId=$CLIENT_ID --set secret.name=easyauth-proxy-$AD_APP_NAME-secret --set secret.azureclientsecret=$CLIENT_SECRET --set appHostName=$APP_HOSTNAME --set tlsSecretName=$TLS_SECRET_NAME easyauth-proxy-$AD_APP_NAME ./charts/easyauth-proxy


kubectl run easyauth-sample-pod --image=docker.io/dakondra/eak-sample:latest --expose --port=80

cat << EOF > ./sample-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: easyauth-sample-ingress-default
  annotations:
    nginx.ingress.kubernetes.io/auth-url: "https://\$host/easyauth/auth"
    nginx.ingress.kubernetes.io/auth-signin: "https://\$host/easyauth/login"
    nginx.ingress.kubernetes.io/auth-response-headers: "x-injected-userinfo,x-injected-name,x-injected-oid,x-injected-preferred-username,x-injected-sub,x-injected-tid,x-injected-email,x-injected-groups,x-injected-scp,x-injected-roles,x-injected-graph"
    cert-manager.io/cluster-issuer: letsencrypt-prod
    #nginx.ingress.kubernetes.io/rewrite-target: /\$1
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - $APP_HOSTNAME
    secretName: $TLS_SECRET_NAME
  rules:
  - host: $APP_HOSTNAME
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: easyauth-sample-pod
            port:
              number: 80
        
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: easyauth-sample-ingress-anonymous
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - $APP_HOSTNAME
    secretName: $TLS_SECRET_NAME
  rules:
  - host: $APP_HOSTNAME
    http:
      paths:
      - path: /Anonymous
        pathType: Prefix
        backend:
          service:
            name: easyauth-sample-pod
            port:
              number: 80
      - path: /css
        pathType: Prefix
        backend:
          service:
            name: easyauth-sample-pod
            port:
              number: 80
      - path: /js
        pathType: Prefix
        backend:
          service:
            name: easyauth-sample-pod
            port:
              number: 80
      - path: /lib
        pathType: Prefix
        backend:
          service:
            name: easyauth-sample-pod
            port:
              number: 80
      - path: /favicon.ico
        pathType: Exact
        backend:
          service:
            name: easyauth-sample-pod
            port:
              number: 80
      - path: /EasyAuthForK8s.Sample.styles.css
        pathType: Exact
        backend:
          service:
            name: easyauth-sample-pod
            port:
              number: 80
       
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: easyauth-sample-ingress-role-required
  annotations:
    nginx.ingress.kubernetes.io/auth-url: "https://\$host/easyauth/auth?role=RoleYouDontHave"
    nginx.ingress.kubernetes.io/auth-signin: "https://\$host/easyauth/login"
    nginx.ingress.kubernetes.io/auth-response-headers: "x-injected-userinfo,x-injected-name,x-injected-oid,x-injected-preferred-username,x-injected-sub,x-injected-tid,x-injected-email,x-injected-groups,x-injected-scp,x-injected-roles,x-injected-graph"
    cert-manager.io/cluster-issuer: letsencrypt-prod
    #nginx.ingress.kubernetes.io/rewrite-target: /\$1
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - $APP_HOSTNAME
    secretName: $TLS_SECRET_NAME
  rules:
  - host: $APP_HOSTNAME
    http:
      paths:
      - path: /RoleRequired
        pathType: Prefix
        backend:
          service:
            name: easyauth-sample-pod
            port:
              number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: easyauth-sample-ingress-role-graph
  annotations:
    nginx.ingress.kubernetes.io/auth-url: "https://\$host/easyauth/auth?scope=User.Read&graph=%2Fme%3F%24select%3DdisplayName%2CjobTitle%2CuserPrincipalName"
    nginx.ingress.kubernetes.io/auth-signin: "https://\$host/easyauth/login"
    nginx.ingress.kubernetes.io/auth-response-headers: "x-injected-userinfo,x-injected-name,x-injected-oid,x-injected-preferred-username,x-injected-sub,x-injected-tid,x-injected-email,x-injected-groups,x-injected-scp,x-injected-roles,x-injected-graph"
    cert-manager.io/cluster-issuer: letsencrypt-prod
    #nginx.ingress.kubernetes.io/rewrite-target: /\$1
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - $APP_HOSTNAME
    secretName: $TLS_SECRET_NAME
  rules:
  - host: $APP_HOSTNAME
    http:
      paths:
      - path: /Graph
        pathType: Prefix
        backend:
          service:
            name: easyauth-sample-pod
            port:
              number: 80       
EOF

cat ./sample-ingress.yaml