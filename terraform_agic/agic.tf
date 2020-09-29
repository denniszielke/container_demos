resource "azurerm_user_assigned_identity" "agicidentity" {
  name = "${var.deployment_name}-agic-id"
  resource_group_name = azurerm_kubernetes_cluster.akstf.node_resource_group
  location            = azurerm_resource_group.aksrg.location
  tags = {
    environment = var.environment
  }
}

resource "azurerm_role_assignment" "agicidentityappgw" {
  scope                = azurerm_application_gateway.appgw.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.agicidentity.principal_id
}

resource "azurerm_role_assignment" "agicidentityappgwgroup" {
  scope                = azurerm_resource_group.aksrg.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.agicidentity.principal_id
}

# https://www.terraform.io/docs/providers/helm/release.html
resource "helm_release" "ingress-azure" {
  name       = "ingress-azure"
  repository = "https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/" 
  chart      = "ingress-azure"
  namespace  = "kube-system"
  force_update = "true"
  timeout = "500"

  set {
    name  = "appgw.name"
    value = azurerm_application_gateway.appgw.name
  }

  set {
    name  = "appgw.resourceGroup"
    value = azurerm_resource_group.aksrg.name
  }

  set {
    name  = "appgw.subscriptionId"
    value = var.subscription_id
  }

  set {
    name  = "appgw.usePrivateIP"
    value = false
  }

  set {
    name  = "appgw.shared"
    value = false
  }

  set {
    name  = "armAuth.type"
    value = "aadPodIdentity"
  }

  set {
    name  = "armAuth.identityClientID"
    value = azurerm_user_assigned_identity.agicidentity.client_id
  }

  set {
    name  = "armAuth.identityResourceID"
    value = azurerm_user_assigned_identity.agicidentity.id
  }

  set {
    name  = "rbac.enabled"
    value = "true"
  }

  set {
    name  = "kubernetes.watchNamespace"
    value = "default"
  }

  depends_on = [azurerm_kubernetes_cluster.akstf, null_resource.after_charts, helm_release.aad-pod-identity]
}