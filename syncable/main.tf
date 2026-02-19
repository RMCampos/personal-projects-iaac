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

variable "release_version" {
  type    = string
  default = "v2026.02.19.12"
}

resource "kubernetes_namespace_v1" "syncable" {
  metadata {
    name = "syncable"
  }
}

resource "kubernetes_secret_v1" "syncable_secrets" {
  metadata {
    name      = "syncable-secrets"
    namespace = kubernetes_namespace_v1.syncable.metadata[0].name
  }

  data = {
    postgres_user       = var.db_user
    postgres_password   = var.db_password
    postgres_db         = var.db_name
  }
}

resource "kubernetes_config_map_v1" "db_init_script" {
  metadata {
    name      = "db-init-script"
    namespace = kubernetes_namespace_v1.syncable.metadata[0].name
  }

  data = {
    "init.sql" = file("${path.module}/init.sql")
  }
}

resource "kubernetes_persistent_volume_claim_v1" "syncable_db_data" {
  metadata {
    name      = "postgres-data-pvc"
    namespace = kubernetes_namespace_v1.syncable.metadata[0].name
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

resource "kubernetes_deployment_v1" "syncable_db" {
  metadata {
    name      = "syncable-db"
    namespace = kubernetes_namespace_v1.syncable.metadata[0].name
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "syncable-db" } }
    template {
      metadata { labels = { app = "syncable-db" } }
      spec {
        container {
          image = "postgres:15.8-bookworm"
          name  = "postgres"
          volume_mount {
            name       = "init-script-volume"     # Must match PART 2
            mount_path = "/docker-entrypoint-initdb.d"
            read_only  = true
          }
          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"
          }
          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.syncable_secrets.metadata[0].name
                key = "postgres_user"
              }
            }
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.syncable_secrets.metadata[0].name
                key = "postgres_password"
              }
            }
          }
          env {
            name = "POSTGRES_DB"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.syncable_secrets.metadata[0].name
                key = "postgres_db"
              }
            }
          }
          port {
            container_port = 5432
          }
          resources {
            limits   = { memory = "512Mi", cpu = "500m" }
            requests = { memory = "256Mi", cpu = "100m" }
          }
        }
        volume {
          name = "init-script-volume"
          config_map {
            name = kubernetes_config_map_v1.db_init_script.metadata[0].name
          }
        }
        volume {
          name = "postgres-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.syncable_db_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "syncable_db_svc" {
  metadata {
    name      = "syncable-db-svc"
    namespace = kubernetes_namespace_v1.syncable.metadata[0].name
  }
  spec {
    selector = { app = "syncable-db" }
    port { port = 5432 }
    type = "ClusterIP"
  }
}

resource "kubernetes_deployment_v1" "syncable_backend" {
  metadata {
    name      = "syncable-backend"
    namespace = kubernetes_namespace_v1.syncable.metadata[0].name
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "syncable-backend" } }
    template {
      metadata { labels = { app = "syncable-backend" } }
      spec {
        container {
          image = "rmcampos/syncable:${var.release_version}"
          name  = "backend"
          liveness_probe {
            http_get {
              path = "/api/health"
              port = 3000
            }
            initial_delay_seconds = 10
            period_seconds        = 5
          }
          readiness_probe {
            http_get {
              path = "/api/health"
              port = 3000
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
          env {
            name = "NODE_ENV"
            value = "production"
          }
          env {
            name  = "DATABASE_URL"
            value = "postgresql://${var.db_user}:${var.db_password}@syncable-db-svc:5432/${var.db_name}"
          }
          resources {
            limits   = { memory = "256Mi", cpu = "500m" }
            requests = { memory = "256Mi", cpu = "250m" }
          }
          
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "syncable_backend_svc" {
  metadata {
    name      = "syncable-backend-svc"
    namespace = kubernetes_namespace_v1.syncable.metadata[0].name
  }
  spec {
    selector = { app = "syncable-backend" }
    port {
      port = 3000
      target_port = 3000
    }
  }
}

resource "kubernetes_ingress_v1" "syncable_ingress" {
  metadata {
    name      = "syncable-ingress"
    namespace = kubernetes_namespace_v1.syncable.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"    = "traefik"
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    }
  }
  spec {
    tls {
      hosts       = ["syncable.darkroasted.vps-kinghost.net"]
      secret_name = "syncable-tls-certs"
    }
    rule {
      host = "syncable.darkroasted.vps-kinghost.net"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.syncable_backend_svc.metadata[0].name
              port { number = 3000 }
            }
          }
        }
      }
    }
  }
}
