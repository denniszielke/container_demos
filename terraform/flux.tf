resource "kubernetes_namespace" "flux_ns" {
  metadata {
    name = "flux"
  }

  depends_on = [azurerm_kubernetes_cluster.akstf]
}

# https://www.terraform.io/docs/providers/kubernetes/r/secret.html
resource "kubernetes_secret" "flux_auth" {
  metadata {
    name = "flux-git-auth"
    namespace = kubernetes_namespace.flux_ns.metadata.0.name
  }
  
  data = {
    GIT_AUTHUSER = var.git_user
    GIT_AUTHKEY = var.git_key
  }
}
