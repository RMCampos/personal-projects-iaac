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

resource "kubernetes_namespace_v1" "dozzle" {
  metadata { name = "dozzle" }
}

# 1. Service Account for Dozzle
resource "kubernetes_service_account_v1" "dozzle" {
  metadata {
    name      = "dozzle"
    namespace = kubernetes_namespace_v1.dozzle.metadata[0].name
  }
}

# 2. Cluster Role to allow log reading
resource "kubernetes_cluster_role_v1" "dozzle_reader" {
  metadata { name = "dozzle-log-reader" }
  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log", "nodes", "events"]
    verbs      = ["get", "list", "watch"]
  }
}

# 3. Bind the Role to the Service Account
resource "kubernetes_cluster_role_binding_v1" "dozzle_binding" {
  metadata { name = "dozzle-global-binding" }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.dozzle_reader.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.dozzle.metadata[0].name
    namespace = kubernetes_namespace_v1.dozzle.metadata[0].name
  }
}

# 4. The Deployment
resource "kubernetes_deployment_v1" "dozzle" {
  metadata {
    name      = "dozzle"
    namespace = kubernetes_namespace_v1.dozzle.metadata[0].name
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "dozzle" } }
    template {
      metadata { labels = { app = "dozzle" } }
      spec {
        service_account_name = kubernetes_service_account_v1.dozzle.metadata[0].name
        container {
          name  = "dozzle"
          image = "amir20/dozzle:latest"
          port { container_port = 8080 }

          env {
            name  = "DOZZLE_REMOTE_HOST"
            value = "k8s"
          }
          env {
            name  = "DOZZLE_LEVEL"
            value = "debug"
          }
          env {
            name  = "DOZZLE_FILTER"
            value = "status=running" 
          }
          resources {
            limits   = { memory = "128Mi", cpu = "200m" }
            requests = { memory = "64Mi", cpu = "50m" }
          }
        }
      }
    }
  }
}

# 5. Service & Ingress
resource "kubernetes_service_v1" "dozzle_svc" {
  metadata {
    name      = "dozzle"
    namespace = kubernetes_namespace_v1.dozzle.metadata[0].name
  }
  spec {
    selector = { app = "dozzle" }
    port { 
      port = 80
      target_port = 8080
    }
  }
}

resource "kubernetes_ingress_v1" "dozzle_ingress" {
  metadata {
    name      = "dozzle-ingress"
    namespace = kubernetes_namespace_v1.dozzle.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"    = "traefik"
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    }
  }
  spec {
    tls {
      hosts       = ["dozzle.darkroasted.vps-kinghost.net"]
      secret_name = "dozzle-tls-certs"
    }
    rule {
      host = "dozzle.darkroasted.vps-kinghost.net"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.dozzle_svc.metadata[0].name
              port { number = 80 }
            }
          }
        }
      }
    }
  }
}
