# ArgoCD installation and configuration
locals {
  normalized_tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
    Project     = var.project_name
    Component   = "argocd"
  })
}

# Kubernetes namespace for ArgoCD
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
    
    labels = {
      "app.kubernetes.io/name"       = "argocd"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = var.project_name
    }
  }
}

# Service account for ArgoCD server
resource "kubernetes_service_account" "argocd_server" {
  metadata {
    name      = "argocd-server"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.argocd_server.arn
    }
    
    labels = {
      "app.kubernetes.io/name"       = "argocd-server"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "server"
    }
  }

  automount_service_account_token = true
}

# Service account for ArgoCD application controller
resource "kubernetes_service_account" "argocd_application_controller" {
  metadata {
    name      = "argocd-application-controller"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.argocd_controller.arn
    }
    
    labels = {
      "app.kubernetes.io/name"       = "argocd-application-controller"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "application-controller"
    }
  }

  automount_service_account_token = true
}

# ArgoCD Helm release
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  create_namespace = false
  wait             = true
  atomic           = true
  timeout          = var.helm_timeout

  values = [templatefile("${path.module}/helm-values/argocd.yaml", {
    server_service_account      = kubernetes_service_account.argocd_server.metadata[0].name
    controller_service_account  = kubernetes_service_account.argocd_application_controller.metadata[0].name
    github_org                 = var.github_org
    github_repo                = var.github_repo
    argocd_domain              = var.argocd_domain
    enable_github_sso          = var.enable_github_sso
    github_client_id           = var.github_client_id
    github_client_secret       = var.github_client_secret
    admin_password_hash        = var.admin_password_hash
    project_name               = var.project_name
    env                        = var.env
  })]

  depends_on = [
    kubernetes_namespace.argocd,
    kubernetes_service_account.argocd_server,
    kubernetes_service_account.argocd_application_controller
  ]
}

# Secret for GitHub repository access
resource "kubernetes_secret" "github_repo_secret" {
  count = var.github_private_key != "" ? 1 : 0

  metadata {
    name      = "${var.project_name}-github-repo"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type          = "git"
    url           = "https://github.com/${var.github_org}/${var.github_repo}"
    password      = var.github_token
    username      = var.github_username
  }

  type = "Opaque"

  depends_on = [helm_release.argocd]
}

# Create initial ArgoCD application for self-management
resource "kubernetes_manifest" "argocd_apps" {
  count = var.enable_app_of_apps ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "${var.project_name}-apps"
      namespace = kubernetes_namespace.argocd.metadata[0].name
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/${var.github_org}/${var.github_repo}"
        targetRevision = var.gitops_branch
        path           = var.argocd_apps_path
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.argocd.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  }

  depends_on = [helm_release.argocd]
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Data source for current AWS region
data "aws_region" "current" {}