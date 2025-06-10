# ArgoCD cluster configuration module
# This module handles registering external EKS clusters with ArgoCD

locals {
  normalized_tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
    Project     = var.project_name
    Component   = "argocd-cluster"
  })
}

# Create service account for ArgoCD in the target cluster
resource "kubernetes_service_account" "argocd_manager" {
  count = var.create_argocd_service_account ? 1 : 0

  metadata {
    name      = var.argocd_service_account_name
    namespace = var.argocd_namespace
    
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.argocd_cluster_manager[0].arn
    }
    
    labels = {
      "app.kubernetes.io/name"       = "argocd-cluster-manager"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "cluster-manager"
    }
  }

  automount_service_account_token = true
}

# Create cluster role for ArgoCD
resource "kubernetes_cluster_role" "argocd_manager" {
  count = var.create_argocd_service_account ? 1 : 0

  metadata {
    name = "${var.project_name}-${var.env}-argocd-manager"
    
    labels = {
      "app.kubernetes.io/name"       = "argocd-cluster-manager"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  # Full cluster admin permissions for ArgoCD
  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }

  rule {
    non_resource_urls = ["*"]
    verbs            = ["*"]
  }
}

# Bind the cluster role to the service account
resource "kubernetes_cluster_role_binding" "argocd_manager" {
  count = var.create_argocd_service_account ? 1 : 0

  metadata {
    name = "${var.project_name}-${var.env}-argocd-manager"
    
    labels = {
      "app.kubernetes.io/name"       = "argocd-cluster-manager"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.argocd_manager[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.argocd_manager[0].metadata[0].name
    namespace = var.argocd_namespace
  }
}

# Create namespace for ArgoCD if it doesn't exist
resource "kubernetes_namespace" "argocd" {
  count = var.create_argocd_namespace ? 1 : 0

  metadata {
    name = var.argocd_namespace
    
    labels = {
      "app.kubernetes.io/name"       = "argocd"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# Store cluster connection details in a secret for ArgoCD
resource "kubernetes_secret" "cluster_config" {
  count = var.create_cluster_secret ? 1 : 0

  metadata {
    name      = "${var.cluster_name}-cluster-config"
    namespace = var.argocd_namespace
    
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
      "app.kubernetes.io/managed-by"   = "terraform"
    }
  }

  data = {
    name   = var.cluster_name
    server = var.cluster_endpoint
    config = jsonencode({
      awsAuthConfig = {
        clusterName = var.cluster_name
        roleARN     = var.cross_account_role_arn
      }
      tlsClientConfig = {
        insecure = false
        caData   = var.cluster_ca_certificate
      }
    })
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.argocd]
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}