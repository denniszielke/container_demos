# https://www.terraform.io/docs/providers/kubernetes/index.html

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.akstf.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.akstf.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.akstf.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.akstf.kube_config.0.cluster_ca_certificate)
}

# https://www.terraform.io/docs/providers/helm/index.html
provider "helm" {
  kubernetes {
    load_config_file = false
    host                   = azurerm_kubernetes_cluster.akstf.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.akstf.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.akstf.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.akstf.kube_config.0.cluster_ca_certificate)
    config_path = "ensure-that-we-never-read-kube-config-from-home-dir"
  }
}

# https://www.terraform.io/docs/providers/helm/repository.html
data "helm_repository" "stable" {
    name = "stable"
    url  = "https://kubernetes-charts.storage.googleapis.com"
}

resource "kubernetes_namespace" "dummy-logger-ns" {
  metadata {
    name = "dummy-logger"
  }

  depends_on = [azurerm_kubernetes_cluster.akstf]
}

resource "kubernetes_service" "dummy-logger-service" {
  metadata {
    name = "dummy-logger-svc-lb"
    namespace = "dummy-logger"
  }
  spec {
    selector = {
      app = "dummy-logger"
    }
    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }

  depends_on = [kubernetes_namespace.dummy-logger-ns]
}

resource "kubernetes_pod" "dummy-logger-pod" {
  metadata {
    name = "dummy-logger"
    namespace = "dummy-logger"
    labels = {
      app = "dummy-logger"
    }
  }

  spec {
    container {
      image = "denniszielke/dummy-logger:latest"
      name  = "dummy-logger"
      image_pull_policy = "Always"
       env {
        name  = "METRICRESET"
        value = "5"
      }
      port {
        container_port = 80
      }
      resources {
        limits {
          cpu    = "200m"
          memory = "200Mi"
        }

        requests {
          cpu    = "100m"
          memory = "100Mi"
        }
      }

    }
  }
    
  depends_on = [kubernetes_namespace.dummy-logger-ns]
}

resource "null_resource" "delay_charts" {
  provisioner "local-exec" {
    command = "sleep 100"
  }
  triggers = {
    "before" = kubernetes_pod.dummy-logger-pod.id
  }
}

resource "null_resource" "after_charts" {
  depends_on = [null_resource.delay_charts]
}