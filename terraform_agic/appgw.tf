resource "azurerm_public_ip" "appgw_ip" {
  name                = "${var.deployment_name}-appgwpip"
  resource_group_name = azurerm_resource_group.aksrg.name
  location            = azurerm_resource_group.aksrg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# https://www.terraform.io/docs/providers/azurerm/r/application_gateway.html
resource "azurerm_application_gateway" "appgw" {
  name                = "${var.deployment_name}-appgw"
  resource_group_name = azurerm_resource_group.aksrg.name
  location            = azurerm_resource_group.aksrg.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.gwnet.id
  }

  frontend_port {
    name = "frontend-port-name"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "frontend-config-name"
    public_ip_address_id = azurerm_public_ip.appgw_ip.id
  }

  backend_address_pool {
    name = "backend-pool-name"
  }

  backend_http_settings {
    name                  = "http-setting-name"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 1
    connection_draining {
      enabled = true
      drain_timeout_sec = 30
    }
  }

  probe {
    name                                        = "probe"
    protocol                                    = "http"
    path                                        = "/"
    interval                                    = "30"
    timeout                                     = "30"
    unhealthy_threshold                         = "3"
    pick_host_name_from_backend_http_settings   = true
  }

  http_listener {
    name                           = "listener-name"
    frontend_ip_configuration_name = "frontend-config-name"
    frontend_port_name             = "frontend-port-name"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "listener-name"
    backend_address_pool_name  = "backend-pool-name"
    backend_http_settings_name = "http-setting-name"
  }
}