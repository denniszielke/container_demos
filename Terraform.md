

TERRAFORM_STORAGE_NAME=
TERRAFORM_STORAGE_KEY=

az storage container create -n tfstate --account-name $TERRAFORM_STORAGE_NAME --account-key $TERRAFORM_STORAGE_KEY

./terraform init -backend-config="storage_account_name=$TERRAFORM_STORAGE_NAME" -backend-config="container_name=tfstate" -backend-config="access_key=$TERRAFORM_STORAGE_KEY" -backend-config="key=codelab.microsoft.tfstate" 


```
./terraform plan -out out.plan
```
```
./terraform apply out.plan
```