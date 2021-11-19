# Creation of Service Principal via Azure Shell

1. Open an azure shell in the browser by authenticating with azure corp credentials and navigating to 
```
https://shell.azure.com
```
2. If this is the first time you are opening an azure shell you will be promted to create a storage account to store your bash history. Select a subscription and create the storage.
![](/img/basic-storage.png)
3. Enter the following command to create a service principal (assuming you have the right credentials/permissions)
```
az ad sp create-for-rbac --skip-assignment --name "kubernetes_sp"
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/${SUBSCRIPTION_ID}" --name "kubernetes_sp"

KUBE_NAME=
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/${SUBSCRIPTION_ID}" --name $KUBE_NAME  --sdk-auth
```
4. The output will look similar to this
```
{
  "appId": "7248f250-0000-0000-0000-dbdeb8400d85",
  "displayName": "azure-cli-2017-10-15-02-20-15",
  "name": "http://azure-cli-2017-10-15-02-20-15",
  "password": "77851d2c-0000-0000-0000-cb3ebc97975a",
  "tenant": "72f988bf-0000-0000-0000-2d7cd011db47"
}
```
5. Remember and copy the appId (this is the service principal client id ) and the password (this is the service principal client secret) because you will need them later for kubernetes-to-azure authentication.

Creation of an SP with the least amount of priviledges:
https://github.com/jsturtevant/aks-examples/tree/master/least-privileged-sp

# Creation of Service Principal via Azure Portal

1. Open the azure portal by authenticating with azure corp credentials and navigating to 
```
https://portal.azure.com
```
2. Select Azure Active Directory

![](/img/select-active-directory.png)

3. Select App registrations

![](/img/select-app-registrations.png)

4. Select New application registrations

![](/img/select-add-app.png)

5. Provide a name that will be identifiyable with your kubernetes cluster (keep it short - no special characters) and remember it. Enter a non-existing sign-on url - this url does not have any effect for the kubernetes cluster - but is a mandatory field.

![](/img/create-app.png)

6. From app registrations look up your new created app by name

![](/img/select-app.png)

7. Copy the ApplicationId for later (this is your service principal client id)

![](/img/copy-app-id.png)

8. Now we need to create a key. Go for Settings

![](/img/select-settings.png)

9. To generate an authentication key select Keys

![](/img/select-keys.png)

10. Provide a description of the key, and a duration for the key. When done, select Save.

![](/img/save-key.png)

11. After saving the key, the value of the key is displayed. Copy this value because you are not able to retrieve the key later. You provide the key value with the application ID to log in as the application. Store the key value where your application can retrieve it.

![](/img/copy-key.png)

This key is your service principal client secret.

## Minimal permission on AKS

1- attach/detach does not happen on nodes. only controller manager. Volume Controller on the node just performers post attach stuff (wait for attach [by waiting for node object to reflect node.VolumesAttached reflecting whatever it is waiting for], mount, format) all does not need SPN  
2- if the node has useInstanceMetadata turned on & no acr secrets then you don't need spn on nodes (iirc acr does not need SPNs only passwords).
3- if the node has  useInstanceMetadata == false; then SPN is needed to call ARM
4- You need contribution on NRP, CRP, DRP in RG scope (or other scope depending on the need to provision stuff outside RG). we nevers said otherwise. in fact o remember there was an excel sheet with table trimmed down to exactly what is needed.
5- This is not the first time i raise this to Jack Francis we can bootstrap clusters with minimum shit on nodes. 
6- please note that OSA can use MSI/explicit identities, it really does not need SPN.
7- as a rule of thumb don't use SPN. We only have it because at some point of time that was the only thing provided, and we still have it because of backcompat 