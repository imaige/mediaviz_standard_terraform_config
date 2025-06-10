# ArgoCD module variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "env" {
  description = "Environment (shared, dev, qa, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region where ArgoCD is deployed"
  type        = string
}

# ArgoCD Configuration
variable "argocd_namespace" {
  description = "Kubernetes namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "7.6.12"
}

variable "argocd_domain" {
  description = "Domain name for ArgoCD server (optional)"
  type        = string
  default     = ""
}

variable "helm_timeout" {
  description = "Timeout for Helm operations in seconds"
  type        = number
  default     = 600
}

# GitHub Integration
variable "github_org" {
  description = "GitHub organization name"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name for GitOps"
  type        = string
}

variable "github_username" {
  description = "GitHub username for repository access"
  type        = string
  default     = ""
}

variable "github_token" {
  description = "GitHub token for repository access"
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_private_key" {
  description = "GitHub SSH private key for repository access"
  type        = string
  sensitive   = true
  default     = ""
}

variable "gitops_branch" {
  description = "Git branch for GitOps manifests"
  type        = string
  default     = "main"
}

variable "argocd_apps_path" {
  description = "Path to ArgoCD applications in Git repository"
  type        = string
  default     = "argocd/applications"
}

# GitHub SSO Configuration
variable "enable_github_sso" {
  description = "Enable GitHub SSO for ArgoCD"
  type        = bool
  default     = false
}

variable "github_client_id" {
  description = "GitHub OAuth App Client ID"
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_client_secret" {
  description = "GitHub OAuth App Client Secret"
  type        = string
  sensitive   = true
  default     = ""
}

# ArgoCD Admin Configuration
variable "admin_password_hash" {
  description = "Bcrypt hash of ArgoCD admin password"
  type        = string
  sensitive   = true
  default     = ""
}

# App of Apps Pattern
variable "enable_app_of_apps" {
  description = "Enable App of Apps pattern for GitOps"
  type        = bool
  default     = true
}

# Cross-Account Cluster Access
variable "external_cluster_configs" {
  description = "Configuration for external EKS clusters to manage"
  type = map(object({
    cluster_endpoint        = string
    cluster_ca_certificate  = string
    cluster_name           = string
    aws_account_id         = string
    cross_account_role_arn = string
    environment            = string
  }))
  default = {}
}

# ECR Access Configuration
variable "shared_ecr_repositories" {
  description = "List of ECR repository names in shared account"
  type        = list(string)
  default = [
    "l-blur-model",
    "l-colors-model", 
    "l-image-comparison-model",
    "l-facial-recognition-model",
    "eks-feature-extraction-model",
    "eks-image-classification-model", 
    "eks-evidence-model",
    "eks-external-api",
    "eks-similarity-model",
    "eks-similarity-set-sorting-service",
    "eks-personhood-model"
  ]
}

# S3 Helm Charts Configuration
variable "helm_charts_bucket_name" {
  description = "S3 bucket name for Helm charts"
  type        = string
  default     = ""
}

# KMS Keys for encryption
variable "kms_key_arns" {
  description = "List of KMS key ARNs for encryption"
  type        = list(string)
  default     = []
}

# OIDC Provider
variable "oidc_provider_arn" {
  description = "OIDC provider ARN for EKS"
  type        = string
  default     = ""
}

variable "oidc_provider" {
  description = "OIDC provider URL for EKS"
  type        = string
  default     = ""
}

# Tags
variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

# ArgoCD Server Configuration
variable "enable_ingress" {
  description = "Enable ingress for ArgoCD server"
  type        = bool
  default     = false
}

variable "ingress_class" {
  description = "Ingress class for ArgoCD server"
  type        = string
  default     = "nginx"
}

variable "enable_tls" {
  description = "Enable TLS for ArgoCD server"
  type        = bool
  default     = true
}

# Resource Limits
variable "server_resources" {
  description = "Resource limits for ArgoCD server"
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
    requests = {
      cpu    = "250m"
      memory = "256Mi"
    }
  }
}

variable "controller_resources" {
  description = "Resource limits for ArgoCD application controller"
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "1000m"
      memory = "1Gi"
    }
    requests = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}