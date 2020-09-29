
provider "azurerm" {
    subscription_id = var.subscription_id
    # client_id       = var.terraform_client_id
    # client_secret   = var.terraform_client_secret
    tenant_id       = var.tenant_id
    features {}
}

# https://www.terraform.io/docs/providers/azurerm/d/resource_group.html
resource "azurerm_resource_group" "aksrg" {
  name     = var.resource_group_name
  location = var.location
    
  tags = {
    environment = var.environment
  }
}