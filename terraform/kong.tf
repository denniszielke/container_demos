
provider "helm" {
  install_tiller = "true"
  service_account = "${kubernetes_service_account.tiller_service_account.metadata.0.name}"
  #tiller_image    = "gcr.io/kubernetes-helm/tiller:v2.14.2"

  kubernetes {
    host                   = "${azurerm_kubernetes_cluster.akstf.kube_config.0.host}"
    client_certificate     = "${base64decode(azurerm_kubernetes_cluster.akstf.kube_config.0.client_certificate)}"
    client_key             = "${base64decode(azurerm_kubernetes_cluster.akstf.kube_config.0.client_key)}"
    cluster_ca_certificate = "${base64decode(azurerm_kubernetes_cluster.akstf.kube_config.0.cluster_ca_certificate)}"
  }
}

# Create Static Public IP Address to be used by Nginx Ingress
resource "azurerm_public_ip" "kong_ingress" {
  name                         = "kong-ingress-pip"
  location                     = "${azurerm_kubernetes_cluster.akstf.location}"
  resource_group_name          = "${azurerm_kubernetes_cluster.akstf.node_resource_group}"
  allocation_method            = "Static"
  domain_name_label            = "${var.dns_prefix}"

  depends_on = ["azurerm_kubernetes_cluster.akstf"]
}

resource "random_string" "kongpsql_password" {
    length  = 16
    special = false
}

# https://www.terraform.io/docs/providers/azurerm/r/postgresql_server.html
resource "azurerm_postgresql_server" "kong_db" {
  name                = "${var.dns_prefix}-kong-db"
  location            = "${azurerm_resource_group.aksrg.location}"
  resource_group_name = "${azurerm_resource_group.aksrg.name}"

  sku {
    name     = "B_Gen5_1"
    capacity = 1
    tier     = "Basic"
    family   = "Gen5"
  }

  storage_profile {
    storage_mb            = 5120
    backup_retention_days = 7
    geo_redundant_backup  = "Disabled"
  }

  administrator_login          = "kongadmin"
  administrator_login_password = "${random_string.kongpsql_password.result}"
  version                      = "9.5"
  ssl_enforcement              = "Enabled"
}

resource "azurerm_postgresql_database" "kong_config_db" {
  name                = "kong"
  resource_group_name = "${azurerm_resource_group.aksrg.name}"
  server_name         = "${azurerm_postgresql_server.kong_db.name}"
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

# https://www.terraform.io/docs/providers/helm/repository.html
data "helm_repository" "stable" {
    name = "stable"
    url  = "https://kubernetes-charts.storage.googleapis.com"
}

# Install Nginx Ingress using Helm Chart
# https://www.terraform.io/docs/providers/helm/release.html
resource "helm_release" "kong_ingress" {
  name       = "kong-ingress"
  repository = "${data.helm_repository.stable.metadata.0.name}"
  chart      = "kong"
  namespace  = "kong"
  force_update = "true"
  timeout = "500"

  set {
    name  = "ingressController.enabled"
    value = "true"
  }

  set {
    name  = "env.database"
    value = "postgres"
  }

  set {
    name  = "postgresql.enabled"
    value = "false"
  }

  set {
    name  = "env.pg_user"
    value = "kongadmin"
  }

  set {
    name  = "env.pg_password"
    value = "${random_string.kongpsql_password.result}"
  }

  set {
    name  = "env.pg_host"
    value = "${azurerm_postgresql_server.kong_db.fqdn}"
  }

  set {
    name  = "proxy.type"
    value = "LoadBalancer"
  }

  set {
    name  = "proxy.loadBalancerIP"
    value = "${azurerm_public_ip.kong_ingress.ip_address}"
  }

  depends_on = ["azurerm_kubernetes_cluster.akstf", "azurerm_public_ip.kong_ingress", "azurerm_postgresql_server.kong_db"]
}