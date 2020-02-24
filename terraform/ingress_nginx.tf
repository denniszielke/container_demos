# Create Static Public IP Address to be used by Nginx Ingress
resource "azurerm_public_ip" "nginx_ingress" {
  name                         = "nginx-ingress-pip"
  location                     = azurerm_kubernetes_cluster.akstf.location
  resource_group_name          = azurerm_kubernetes_cluster.akstf.node_resource_group
  allocation_method            = "Static"
  sku                          = "Standard"
  domain_name_label            = var.dns_prefix

  depends_on = [azurerm_kubernetes_cluster.akstf]
}

resource "kubernetes_namespace" "nginx-ns" {
  metadata {
    name = "nginx"
  }

  depends_on = [azurerm_kubernetes_cluster.akstf]
}

# Install Nginx Ingress using Helm Chart
# https://www.terraform.io/docs/providers/helm/release.html
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = data.helm_repository.stable.metadata.0.name
  chart      = "nginx-ingress"
  namespace  = "nginx"
  force_update = "true"
  timeout = "500"

  set {
    name  = "controller.service.externalTrafficPolicy"
    value = "Local"
  }

  set {
    name  = "controller.service.loadBalancerIP"
    value = azurerm_public_ip.nginx_ingress.ip_address
  }
  
  set {
    name  = "controller.replicaCount"
    value = "2"
  }

  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  depends_on = [azurerm_kubernetes_cluster.akstf, kubernetes_namespace.nginx-ns, azurerm_public_ip.nginx_ingress, null_resource.after_charts]
}
