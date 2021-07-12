

https://learn.hashicorp.com/tutorials/vault/getting-started-install

brew tap hashicorp/tap
brew install hashicorp/tap/vault

brew upgrade hashicorp/tap/vault


kubectl create namespace vault

kubectl --namespace='vault' get all

helm repo add hashicorp https://helm.releases.hashicorp.com

helm search repo hashicorp/vault

helm install vault hashicorp/vault --namespace vault

az ad sp create-for-rbac --name http://vaultsp --role reader --scopes /subscriptions/AZURE_SUBSCRIPTION_ID


helm install vault hashicorp/vault \
    --namespace vault \
    --set "server.ha.enabled=true" \
    --set "server.ha.replicas=5" \
    --dry-run

helm delete vault -n vault

helm upgrade vault hashicorp/vault --install \
    --namespace vault \
    -f hashicorpvault.yaml \
    --dry-run



export VAULT_ADDR='http://[::]:8200'

The unseal key and root token are displayed below in case you want to
seal/unseal the Vault or re-authenticate.

Unseal Key: =
Root Token: root

kubectl get pods --selector='app.kubernetes.io/name=vault' --namespace=' vault'

kubectl exec --stdin=true -n vault --tty=true vault-0 -- vault operator init

kubectl port-forward vault-0 8200:8200 -n vault


Error parsing Seal configuration: error fetching Azure Key Vault wrapper key information: azure.BearerAuthorizer#WithAuthorization: Failed to refresh the Token for request to https://dvadzvault.vault.azure.net/keys/vaultkey/?api-version=7.0: StatusCode=400 -- Original Error: adal: Refresh request failed. Status Code = '400'. Response body: {"error":"invalid_request","error_description":"Multiple user assigned identities exist, please specify the clientId / resourceId of the identity in the token request"} Endpoint http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net
2021-06-24T12:04:39.565Z [INFO]  proxy environment: http_proxy="" https_proxy="" no_proxy=""