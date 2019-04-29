# https://www.terraform.io/docs/providers/azurerm/r/role_assignment.html
resource "azurerm_role_assignment" "aksacrrole" {
  scope                = "${data.azurerm_subscription.primary.id}"
  role_definition_name = "Reader"
  principal_id         = "${data.azurerm_client_config.test.service_principal_object_id}"
  
  depends_on = ["azurerm_kubernetes_cluster.akstf"]
}

# https://www.terraform.io/docs/providers/azurerm/r/container_registry.html

resource "azurerm_container_registry" "aksacr" {
  name                     = "${var.dns_prefix}acr"
  resource_group_name      = "${azurerm_resource_group.aksrg.name}"
  location                 = "${azurerm_resource_group.aksrg.location}"
  sku                      = "Standard"
  admin_enabled            = true
}