terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0" 
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_namespace_v1" "timez_people" {
  metadata {
    name = "timez-people"
  }
}

resource "kubernetes_deployment_v1" "timez_people" {
  metadata {
    name      = "timez-people"
    namespace = kubernetes_namespace_v1.timez_people.metadata[0].name
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "timez-people"
      }
    }
    template {
      metadata {
        labels = {
          app = "timez-people"
        }
      }
      spec {
        container {
          image = "ghcr.io/rmcampos/timez-people:latest"
          name  = "timez-people"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "timez_people_svc" {
  metadata {
    name      = "timez-people-service"
    namespace = kubernetes_namespace_v1.timez_people.metadata[0].name
  }
  spec {
    selector = {
      app = "timez-people"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "timez_people_ingress" {
  metadata {
    name      = "timez-people-ingress"
    namespace = kubernetes_namespace_v1.timez_people.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"
    }
  }
  spec {
    rule {
      host = "timez.darkroasted.vps-kinghost.net"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.timez_people_svc.metadata[0].name 
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
