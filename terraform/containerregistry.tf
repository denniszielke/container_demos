# https://www.terraform.io/docs/providers/azurerm/r/role_assignment.html
resource "azurerm_role_assignment" "aksacrrole" {
  scope                = "${azurerm_container_registry.aksacr.id}"
  role_definition_name = "Reader"
  principal_id         = "${azuread_service_principal.aks_sp.id}"
  # principal_id         = "${var.aks_client_id}"
  
  depends_on = ["azuread_service_principal.aks_sp", "azurerm_container_registry.aksacr", "azurerm_subnet.aksnet"]
}

# https://www.terraform.io/docs/providers/azurerm/r/container_registry.html

resource "azurerm_container_registry" "aksacr" {
  name                     = "${var.dns_prefix}acr"
  resource_group_name      = "${azurerm_resource_group.aksrg.name}"
  location                 = "${azurerm_resource_group.aksrg.location}"
  sku                      = "Standard"
  admin_enabled            = true
}