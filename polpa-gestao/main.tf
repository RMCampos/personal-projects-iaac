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

variable "cpf_cnpj_api_token" {
  type      = string
  sensitive = true
}

variable "backend_image" {
  type    = string
  default = "ghcr.io/rmcampos/polpa-gestao/backend:v2026.03.15.5"
}

variable "migrations_image" {
  type    = string
  default = "ghcr.io/rmcampos/polpa-gestao/backend:v2026.03.15.5-prisma"
}

resource "kubernetes_namespace_v1" "polpa_gestao" {
  metadata {
    name = "polpa-gestao"
  }
}

resource "kubernetes_secret_v1" "polpa_gestao_secrets" {
  metadata {
    name      = "polpa-gestao-secrets"
    namespace = kubernetes_namespace_v1.polpa_gestao.metadata[0].name
  }

  data = {
    postgres_user       = var.db_user
    postgres_password   = var.db_password
    postgres_db         = var.db_name
    cpf_cnpj_api_token  = var.cpf_cnpj_api_token
  }
}

resource "kubernetes_persistent_volume_claim_v1" "polpa_gestao_db_data" {
  metadata {
    name      = "postgres-data-pvc"
    namespace = kubernetes_namespace_v1.polpa_gestao.metadata[0].name
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

resource "kubernetes_deployment_v1" "polpa_gestao_db" {
  metadata {
    name      = "polpa-gestao-db"
    namespace = kubernetes_namespace_v1.polpa_gestao.metadata[0].name
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "polpa-gestao-db" } }
    template {
      metadata { labels = { app = "polpa-gestao-db" } }
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
                name = kubernetes_secret_v1.polpa_gestao_secrets.metadata[0].name
                key = "postgres_user"
              }
            }
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.polpa_gestao_secrets.metadata[0].name
                key = "postgres_password"
              }
            }
          }
          env {
            name = "POSTGRES_DB"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.polpa_gestao_secrets.metadata[0].name
                key = "postgres_db"
              }
            }
          }
          port { container_port = 5432 }
        }
        volume {
          name = "postgres-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.polpa_gestao_db_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "polpa_gestao_db_svc" {
  metadata {
    name      = "polpa-gestao-db-svc"
    namespace = kubernetes_namespace_v1.polpa_gestao.metadata[0].name
  }
  spec {
    selector = { app = "polpa-gestao-db" }
    port { port = 5432 }
    type = "ClusterIP"
  }
}

resource "kubernetes_deployment_v1" "polpa_gestao_backend" {
  metadata {
    name      = "polpa-gestao-backend"
    namespace = kubernetes_namespace_v1.polpa_gestao.metadata[0].name
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "polpa-gestao-backend" } }
    template {
      metadata { labels = { app = "polpa-gestao-backend" } }
      spec {
        init_container {
          name        = "prisma-migrate"
          image       = var.migrations_image
          command     = ["npx", "prisma", "db", "push"]
          env {
            name = "DATABASE_URL"
            value = "postgresql://${var.db_user}:${var.db_password}@polpa-gestao-db-svc:5432/${var.db_name}?schema=public"
          }
        }
        container {
          image = var.backend_image
          name  = "app"
          env {
            name = "DATABASE_URL"
            value = "postgresql://${var.db_user}:${var.db_password}@polpa-gestao-db-svc:5432/${var.db_name}?schema=public"
          }
          env {
            name  = "PORT"
            value = "3000"
          }
          env {
            name  = "HOSTNAME"
            value = "0.0.0.0"
          }
          resources {
            limits   = { memory = "512Mi", cpu = "500m" }
            requests = { memory = "256Mi", cpu = "100m" }
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
      }
    }
  }
}

resource "kubernetes_service_v1" "polpa_gestao_backend_svc" {
  metadata {
    name      = "polpa-gestao-backend-svc"
    namespace = kubernetes_namespace_v1.polpa_gestao.metadata[0].name
  }
  spec {
    selector = { app = "polpa-gestao-backend" }
    port {
      port = 3000
      target_port = 3000
    }
  }
}

resource "kubernetes_deployment_v1" "polpa_gestao_frontend" {
  metadata {
    name      = "polpa-gestao-frontend"
    namespace = kubernetes_namespace_v1.polpa_gestao.metadata[0].name
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "polpa-gestao-frontend" } }
    template {
      metadata { labels = { app = "polpa-gestao-frontend" } }
      spec {
        container {
          image = "ghcr.io/rmcampos/polpa-gestao/frontend:v2026.03.16.3"
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

resource "kubernetes_service_v1" "polpa_gestao_frontend_svc" {
  metadata {
    name      = "polpa-gestao-frontend-svc"
    namespace = kubernetes_namespace_v1.polpa_gestao.metadata[0].name
  }
  spec {
    selector = { app = "polpa-gestao-frontend" }
    port {
      port = 80
      target_port = 80
    }
    type = "ClusterIP"
  }
}

# Unified Ingress for App and API
resource "kubernetes_ingress_v1" "polpa_gestao_ingress" {
  metadata {
    name      = "polpa-gestao-ingress"
    namespace = kubernetes_namespace_v1.polpa_gestao.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"    = "traefik"
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    }
  }
  spec {
    tls {
      hosts       = ["polpa-gestao.darkroasted.vps-kinghost.net", "polpaapi-gestao.darkroasted.vps-kinghost.net"]
      secret_name = "polpa-gestao-tls-certs"
    }
    rule {
      host = "polpa-gestao.darkroasted.vps-kinghost.net"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.polpa_gestao_frontend_svc.metadata[0].name
              port { number = 80 }
            }
          }
        }
      }
    }
    rule {
      host = "polpaapi-gestao.darkroasted.vps-kinghost.net"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.polpa_gestao_backend_svc.metadata[0].name
              port { number = 3000 }
            }
          }
        }
      }
    }
  }
}
