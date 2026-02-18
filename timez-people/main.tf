# 1. The Deployment (The "How many" and "What image")
resource "kubernetes_deployment" "timez_people" {
  metadata {
    name      = "timez-people"
    namespace = kubernetes_namespace.project_a.metadata[0].name
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

# 2. The Service (The internal Load Balancer)
resource "kubernetes_service" "timez_people_svc" {
  metadata {
    name      = "timez-people-service"
    namespace = kubernetes_namespace.project_a.metadata[0].name
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

# 3. The Ingress (The Entry Point)
resource "kubernetes_ingress_v1" "timez_people_ingress" {
  metadata {
    name      = "timez-people-ingress"
    namespace = kubernetes_namespace.project_a.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"
    }
  }
  spec {
    rule {
      host = "timez.darkroasted.vps-kinghost.net"
      http {
        path {
          path = "/"
          backend {
            service {
              name = kubernetes_service.timez_people_svc.metadata[0].name
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
