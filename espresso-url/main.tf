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

variable "db_user" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_name" {
  type      = string
  sensitive = true
}

variable "backend_image" {
  type      = string
  default   = "ghcr.io/rmcampos/espresso-url/backend:api-v2026.02.23.5"
}

resource "kubernetes_namespace_v1" "espresso-url" {
  metadata {
    name = "espresso-url"
  }
}

resource "kubernetes_secret_v1" "espresso_url_secrets" {
  metadata {
    name      = "espresso-url-secrets"
    namespace = kubernetes_namespace_v1.espresso-url.metadata[0].name
  }

  data = {
    postgres_user       = var.db_user
    postgres_password   = var.db_password
    postgres_db         = var.db_name
  }
}

resource "kubernetes_persistent_volume_claim_v1" "espresso_url_db_data" {
  metadata {
    name      = "postgres-data-pvc"
    namespace = kubernetes_namespace_v1.espresso-url.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "espresso_url_db" {
  metadata {
    name      = "espresso-url-db"
    namespace = kubernetes_namespace_v1.espresso-url.metadata[0].name
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "espresso-url-db" } }
    template {
      metadata { labels = { app = "espresso-url-db" } }
      spec {
        container {
          image = "postgres:16"
          name  = "postgres"
          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"
          }
          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.espresso_url_secrets.metadata[0].name
                key = "postgres_user"
              }
            }
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.espresso_url_secrets.metadata[0].name
                key = "postgres_password"
              }
            }
          }
          env {
            name = "POSTGRES_DB"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.espresso_url_secrets.metadata[0].name
                key = "postgres_db"
              }
            }
          }
          port { container_port = 5432 }
        }
        volume {
          name = "postgres-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.espresso_url_db_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "espresso_url_db_svc" {
  metadata {
    name      = "espresso-url-db-svc"
    namespace = kubernetes_namespace_v1.espresso-url.metadata[0].name
  }
  spec {
    selector = { app = "espresso-url-db" }
    port { port = 5432 }
    type = "ClusterIP"
  }
}

resource "kubernetes_deployment_v1" "espresso_url_backend" {
  metadata {
    name      = "espresso-url-backend"
    namespace = kubernetes_namespace_v1.espresso-url.metadata[0].name
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "espresso-url-backend" } }
    template {
      metadata { labels = { app = "espresso-url-backend" } }
      spec {
        init_container {
          name = "prisma-migrate"
          image = var.backend_image
          command = ["sh", "-c", "prisma migrate deploy"]
          env {
            name = "DATABASE_URL"
            value = "postgresql://${var.db_user}:${var.db_password}@espresso-url-db-svc:5432/${var.db_name}&schema=public"
          }
        }
        container {
          image = var.backend_image
          name  = "backend"
          env {
            name = "DATABASE_URL"
            value = "postgresql://${var.db_user}:${var.db_password}@espresso-url-db-svc:5432/${var.db_name}&schema=public"
          }
          resources {
            limits   = { memory = "128Mi", cpu = "250m" }
            requests = { memory = "128Mi", cpu = "250m" }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "espresso_url_backend_svc" {
  metadata {
    name      = "espresso-url-backend-svc"
    namespace = kubernetes_namespace_v1.espresso-url.metadata[0].name
  }
  spec {
    selector = { app = "espresso-url-backend" }
    port {
      port = 3000
      target_port = 3000
    }
  }
}

resource "kubernetes_deployment_v1" "espresso_url_frontend" {
  metadata {
    name      = "espresso-url-frontend"
    namespace = kubernetes_namespace_v1.espresso-url.metadata[0].name
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "espresso-url-frontend" } }
    template {
      metadata { labels = { app = "espresso-url-frontend" } }
      spec {
        container {
          image = "ghcr.io/rmcampos/espresso-url/frontend:app-v2026.02.23.6"
          name  = "frontend"
          port { container_port = 5173 }
          env {
            name  = "VITE_BACKEND_SERVER"
            value = "https://espresso-urlapi.darkroasted.vps-kinghost.net"
          }
          resources {
            limits   = { memory = "128Mi", cpu = "250m" }
            requests = { memory = "128Mi", cpu = "250m" }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "espresso_url_frontend_svc" {
  metadata {
    name      = "espresso-url-frontend-svc"
    namespace = kubernetes_namespace_v1.espresso-url.metadata[0].name
  }
  spec {
    selector = { app = "espresso-url-frontend" }
    port {
      port = 5173
      target_port = 5173
    }
    type = "ClusterIP"
  }
}

# Unified Ingress for App and API
resource "kubernetes_ingress_v1" "espresso_url_ingress" {
  metadata {
    name      = "espresso-url-ingress"
    namespace = kubernetes_namespace_v1.espresso-url.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"    = "traefik"
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    }
  }
  spec {
    tls {
      hosts       = ["espresso-url.darkroasted.vps-kinghost.net", "espresso-urlapi.darkroasted.vps-kinghost.net"]
      secret_name = "tasknote-tls-certs"
    }
    rule {
      host = "espresso-url.darkroasted.vps-kinghost.net"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.espresso_url_frontend_svc.metadata[0].name
              port { number = 5173 }
            }
          }
        }
      }
    }
    rule {
      host = "espresso-urlapi.darkroasted.vps-kinghost.net"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.espresso_url_backend_svc.metadata[0].name
              port { number = 3000 }
            }
          }
        }
      }
    }
  }
}
