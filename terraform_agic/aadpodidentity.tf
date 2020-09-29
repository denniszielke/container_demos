resource "azurerm_role_assignment" "podidentitycontroller" {
  scope                = azurerm_resource_group.aksrg.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_kubernetes_cluster.akstf.identity.0.principal_id

  depends_on = [azurerm_kubernetes_cluster.akstf]
}

resource "azurerm_role_assignment" "podidentitykubelet" {
  scope                = azurerm_resource_group.aksrg.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_kubernetes_cluster.akstf.kubelet_identity[0].object_id

  depends_on = [azurerm_kubernetes_cluster.akstf]
}


# resource "azurerm_role_assignment" "podidentitykubeletvms" {
#   scope                = azurerm_kubernetes_cluster.akstf.node_resource_group
#   role_definition_name = "Virtual Machine Contributor"
#   principal_id         = azurerm_kubernetes_cluster.akstf.kubelet_identity[0].object_id

#   depends_on = [azurerm_kubernetes_cluster.akstf]
# }


# https://www.terraform.io/docs/providers/helm/release.html
resource "helm_release" "aad-pod-identity" {
  name       = "aad-pod-identity"
  repository = "https://kubernetes-charts.storage.googleapis.com" 
  chart      = "aad-pod-identity"
  namespace  = "kube-system"
  force_update = "true"
  timeout = "500"

  depends_on = [azurerm_kubernetes_cluster.akstf, null_resource.after_charts]
}