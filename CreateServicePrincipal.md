# Creation of Service Principal via Azure Shell

1. Open an azure shell in the browser by authenticating with azure corp credentials and navigating to 
```
https://shell.azure.com
```
2. If this is the first time you are opening an azure shell you will be promted to create a storage account to store your bash history. Select a subscription and create the storage.
![](/img/basic-storage.png)
3. Enter the following command to create a service principal (assuming you have the right credentials/permissions)
```
az ad sp create-for-rbac --skip-assignment
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