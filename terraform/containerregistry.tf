# https://www.terraform.io/docs/providers/azurerm/r/role_assignment.html
resource "azurerm_role_assignment" "aksacrrole" {
  scope                = azurerm_container_registry.aksacr.id
  role_definition_name = "Reader"
  principal_id         = azurerm_kubernetes_cluster.akstf.kubelet_identity[0].object_id
  # principal_id         = var.aks_client_id
  
  depends_on = [azurerm_container_registry.aksacr, azurerm_subnet.aksnet, azurerm_kubernetes_cluster.akstf]
}

# https://www.terraform.io/docs/providers/azurerm/r/container_registry.html

resource "azurerm_container_registry" "aksacr" {
  name                     = "${var.dns_prefix}acr"
  resource_group_name      = azurerm_resource_group.aksrg.name
  location                 = azurerm_resource_group.aksrg.location
  sku                      = "Premium"
  admin_enabled            = true
  # network_rule_set = {
  #   default_action          = Deny
  #   subnet_id               = azurerm_subnet.aksnet.id
  # }

  tags = {
    environment = var.environment
  }
}