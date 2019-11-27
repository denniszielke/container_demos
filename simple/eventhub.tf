# https://www.terraform.io/docs/providers/azurerm/r/eventhub.html
resource "azurerm_eventhub_namespace" "eventhubns" {
  name                = "${var.dns_prefix}ns"
  location            = azurerm_resource_group.aksrg.location
  resource_group_name = azurerm_resource_group.aksrg.name
  sku                 = "Standard"
  capacity            = 1

  tags = {
    Environment = var.environment
  }
}

resource "azurerm_eventhub" "eventhub" {
  name                = "${var.dns_prefix}ns"
  namespace_name      = azurerm_eventhub_namespace.eventhubns.name
  resource_group_name = azurerm_resource_group.aksrg.name
  partition_count     = 2
  message_retention   = 1
}