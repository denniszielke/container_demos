data "template_file" "traefik" {
  template = "${file("${path.module}/traefik.yaml.tmpl")}"

  vars = {
    jaeger_agent_endpoint = "${var.jaeger_agent_endpoint}"
    prometheus_enabled    = "true"
    ssl_enabled           = "${var.ssl_enabled}"
    ssl_enforced          = "${var.ssl_enforced}"
    ssl_cert_base64       = "${var.ssl_cert_base64}"
    ssl_key_base64        = "${var.ssl_key_base64}"
  }
}

resource "null_resource" "generate_traefik_config" {
  provisioner "local-exec" {
    command = "echo '${data.template_file.traefik.rendered}' > ${path.module}/traefik.yaml"
  }

  depends_on = ["data.template_file.traefik"]
}

provider "helm" {
  install_tiller = "true"
  service_account = "${kubernetes_service_account.tiller_service_account.metadata.0.name}"
  # tiller_image    = "gcr.io/kubernetes-helm/tiller:v2.14.2"

  kubernetes {
    host                   = "${azurerm_kubernetes_cluster.akstf.kube_config.0.host}"
    client_certificate     = "${base64decode(azurerm_kubernetes_cluster.akstf.kube_config.0.client_certificate)}"
    client_key             = "${base64decode(azurerm_kubernetes_cluster.akstf.kube_config.0.client_key)}"
    cluster_ca_certificate = "${base64decode(azurerm_kubernetes_cluster.akstf.kube_config.0.cluster_ca_certificate)}"
  }
}

# Create Static Public IP Address to be used by Traefik Ingress
resource "azurerm_public_ip" "traefik_ingress" {
  name                         = "traefik-ingress-pip"
  location                     = "${azurerm_kubernetes_cluster.akstf.location}"
  resource_group_name          = "${azurerm_kubernetes_cluster.akstf.node_resource_group}"
  allocation_method            = "Static"
  domain_name_label            = "${var.dns_prefix}"

  depends_on = ["azurerm_kubernetes_cluster.akstf"]
}

# https://www.terraform.io/docs/providers/helm/repository.html
data "helm_repository" "stable" {
    name = "stable"
    url  = "https://kubernetes-charts.storage.googleapis.com"
}

# Install traefik Ingress using Helm Chart
# https://github.com/helm/charts/tree/master/stable/traefik
# https://www.terraform.io/docs/providers/helm/release.html
resource "helm_release" "traefik_ingress" {
  name       = "traefik_ingress"
  repository = "${data.helm_repository.stable.metadata.0.name}"
  chart      = "nginx-ingress"
  namespace  = "kube-system"
  force_update = "true"
  timeout = "500"

  values = [
    "${file("${path.module}/traefik.yaml")}",
  ]

  set {
    name  = "replicas"
    value = "${var.ingress_replica_count}"
  }

  set {
    name  = "rbac.create"
    value = "true"
  }

  set {
    name  = "controller.service.externalTrafficPolicy"
    value = "Local"
  }

  set {
    name  = "controller.service.loadBalancerIP"
    value = "${azurerm_public_ip.nginx_ingress.ip_address}"
  }
  
  set {
    name  = "controller.replicaCount"
    value = "2"
  }

  depends_on = ["azurerm_kubernetes_cluster.akstf", "azurerm_public_ip.nginx_ingress", "null_resource.generate_traefik_config", "data.template_file.traefik"]
}