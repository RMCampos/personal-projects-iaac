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

variable "jwt_secret" {
  type      = string
  sensitive = true
}

variable "giphy_api_key" {
  type      = string
  sensitive = true
}

variable "backend_image" {
  type    = string
  default = "ghcr.io/rmcampos/gif-mood/backend:api-v2026.03.27.2"
}

variable "migrations_image" {
  type    = string
  default = "ghcr.io/rmcampos/gif-mood/backend:api-v2026.03.27.2-prisma"
}

resource "kubernetes_namespace_v1" "gif_mood" {
  metadata {
    name = "gif-mood"
  }
}

resource "kubernetes_secret_v1" "gif_mood_secrets" {
  metadata {
    name      = "gif-mood-secrets"
    namespace = kubernetes_namespace_v1.gif_mood.metadata[0].name
  }

  data = {
    postgres_user       = var.db_user
    postgres_password   = var.db_password
    postgres_db         = var.db_name
    jwt_secret          = var.jwt_secret
    giphy_api_key       = var.giphy_api_key
  }
}

resource "kubernetes_persistent_volume_claim_v1" "gif_mood_db_data" {
  metadata {
    name      = "postgres-data-pvc"
    namespace = kubernetes_namespace_v1.gif_mood.metadata[0].name
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

resource "kubernetes_persistent_volume_claim_v1" "gif_mood_uploads_data" {
  metadata {
    name      = "uploads-data-pvc"
    namespace = kubernetes_namespace_v1.gif_mood.metadata[0].name
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

resource "kubernetes_deployment_v1" "gif_mood_db" {
  metadata {
    name      = "gif-mood-db"
    namespace = kubernetes_namespace_v1.gif_mood.metadata[0].name
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "gif-mood-db" } }
    template {
      metadata { labels = { app = "gif-mood-db" } }
      spec {
        container {
          image = "postgres:16-alpine"
          name  = "postgres"
          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"
          }
          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.gif_mood_secrets.metadata[0].name
                key = "postgres_user"
              }
            }
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.gif_mood_secrets.metadata[0].name
                key = "postgres_password"
              }
            }
          }
          env {
            name = "POSTGRES_DB"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.gif_mood_secrets.metadata[0].name
                key = "postgres_db"
              }
            }
          }
          port { container_port = 5432 }
        }
        volume {
          name = "postgres-storage"
          persistent_volume_claim {
            claim_name = "postgres-data-pvc"
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "gif_mood_db_svc" {
  metadata {
    name      = "gif-mood-db-svc"
    namespace = kubernetes_namespace_v1.gif_mood.metadata[0].name
  }
  spec {
    selector = { app = "gif-mood-db" }
    port { port = 5432 }
    type = "ClusterIP"
  }
}

resource "kubernetes_deployment_v1" "gif_mood_backend" {
  metadata {
    name      = "gif-mood-backend"
    namespace = kubernetes_namespace_v1.gif_mood.metadata[0].name
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "gif-mood-backend" } }
    template {
      metadata { labels = { app = "gif-mood-backend" } }
      spec {
        init_container {
          name        = "prisma-migrate"
          image       = var.migrations_image
          command     = ["npx", "prisma", "db", "push"]
          env {
            name = "DATABASE_URL"
            value = "postgresql://${var.db_user}:${var.db_password}@gif-mood-db-svc:5432/${var.db_name}"
          }
        }
        container {
          image = var.backend_image
          name  = "app"
          volume_mount {
            name       = "uploads-storage"
            mount_path = "/uploads"
          }
          env {
            name = "DATABASE_URL"
            value = "postgresql://${var.db_user}:${var.db_password}@gif-mood-db-svc:5432/${var.db_name}"
          }
          env {
            name  = "PORT"
            value = "3000"
          }
          env {
            name = "JWT_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.gif_mood_secrets.metadata[0].name
                key = "jwt_secret"
              }
            }
          }
          env {
            name = "GIPHY_API_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.gif_mood_secrets.metadata[0].name
                key = "giphy_api_key"
              }
            }
          }
          env {
            name = "UPLOAD_DIR"
            value = "/uploads"
          }
          env {
            name = "CORS_ORIGIN"
            value = "https://gif-mood.darkroasted.vps-kinghost.net"
          }
          resources {
            limits   = { memory = "256Mi", cpu = "300m" }
            requests = { memory = "128Mi", cpu = "100m" }
          }
          readiness_probe {
            exec {
              command = ["node", "healthcheck.js"]
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            failure_threshold     = 3
          }
          liveness_probe {
            exec {
              command = ["node", "healthcheck.js"]
            }
            initial_delay_seconds = 15
            period_seconds        = 10
            failure_threshold     = 3
          }
        }
        volume {
          name = "uploads-storage"
          persistent_volume_claim {
            claim_name = "uploads-data-pvc"
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "gif_mood_backend_svc" {
  metadata {
    name      = "gif-mood-backend-svc"
    namespace = kubernetes_namespace_v1.gif_mood.metadata[0].name
  }
  spec {
    selector = { app = "gif-mood-backend" }
    port {
      port = 3000
      target_port = 3000
    }
  }
}

resource "kubernetes_deployment_v1" "gif_mood_frontend" {
  metadata {
    name      = "gif-mood-frontend"
    namespace = kubernetes_namespace_v1.gif_mood.metadata[0].name
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "gif-mood-frontend" } }
    template {
      metadata { labels = { app = "gif-mood-frontend" } }
      spec {
        container {
          image = "ghcr.io/rmcampos/gif-mood/frontend:app-v2026.03.27.3"
          name  = "frontend"
          port { container_port = 80 }
          resources {
            limits   = { memory = "128Mi", cpu = "150m" }
            requests = { memory = "128Mi", cpu = "100m" }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "gif_mood_frontend_svc" {
  metadata {
    name      = "gif-mood-frontend-svc"
    namespace = kubernetes_namespace_v1.gif_mood.metadata[0].name
  }
  spec {
    selector = { app = "gif-mood-frontend" }
    port {
      port = 80
      target_port = 80
    }
    type = "ClusterIP"
  }
}

# Unified Ingress for App and API
resource "kubernetes_ingress_v1" "gif_mood_ingress" {
  metadata {
    name      = "gif-mood-ingress"
    namespace = kubernetes_namespace_v1.gif_mood.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"    = "traefik"
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    }
  }
  spec {
    tls {
      hosts       = ["gif-mood.darkroasted.vps-kinghost.net", "gif-moodapi.darkroasted.vps-kinghost.net"]
      secret_name = "gif-mood-tls-certs"
    }
    rule {
      host = "gif-mood.darkroasted.vps-kinghost.net"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.gif_mood_frontend_svc.metadata[0].name
              port { number = 80 }
            }
          }
        }
      }
    }
    rule {
      host = "gif-moodapi.darkroasted.vps-kinghost.net"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.gif_mood_backend_svc.metadata[0].name
              port { number = 3000 }
            }
          }
        }
      }
    }
  }
}
