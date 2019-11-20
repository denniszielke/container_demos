resource "azurerm_key_vault" "aksvauls" {
  name                        = "${var.dns_prefix}-vault"
  location                    = azurerm_resource_group.aksrg.location
  resource_group_name         = azurerm_resource_group.aksrg.name
  enabled_for_disk_encryption = false
  tenant_id                   = var.tenant_id

  sku_name = "standard"

  access_policy {
    tenant_id = var.tenant_id
    object_id = azuread_application.aks_app.application_id

    key_permissions = [
      "get",
    ]

    secret_permissions = [
      "get",
    ]
  }

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = {
    Environment = var.environment
  }
}