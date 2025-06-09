# Variables for ArgoCD cluster configuration module

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "env" {
  description = "Environment (dev, qa, prod)"
  type        = string
}

# Cluster Configuration
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster endpoint URL"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "EKS cluster CA certificate data (base64 encoded)"
  type        = string
  default     = ""
}

# ArgoCD Configuration
variable "argocd_namespace" {
  description = "Kubernetes namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "argocd_service_account_name" {
  description = "Name of the ArgoCD service account in this cluster"
  type        = string
  default     = "argocd-cluster-manager"
}

# Feature Flags
variable "create_argocd_service_account" {
  description = "Whether to create ArgoCD service account in this cluster"
  type        = bool
  default     = true
}

variable "create_argocd_namespace" {
  description = "Whether to create ArgoCD namespace in this cluster"
  type        = bool
  default     = true
}

variable "create_cluster_secret" {
  description = "Whether to create cluster connection secret"
  type        = bool
  default     = false
}

# Cross-Account Configuration
variable "shared_account_id" {
  description = "AWS account ID of the shared services account"
  type        = string
  default     = ""
}

variable "cross_account_role_arn" {
  description = "ARN of the cross-account role for shared services access"
  type        = string
  default     = ""
}

# OIDC Configuration
variable "oidc_provider_arn" {
  description = "OIDC provider ARN for EKS"
  type        = string
}

variable "oidc_provider" {
  description = "OIDC provider URL for EKS"
  type        = string
}

# ECR Configuration
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

# S3 Configuration
variable "helm_charts_bucket_name" {
  description = "S3 bucket name for Helm charts"
  type        = string
  default     = ""
}

# KMS Configuration
variable "kms_key_arns" {
  description = "List of KMS key ARNs for encryption"
  type        = list(string)
  default     = []
}

# Tags
variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

# RBAC Configuration
variable "argocd_cluster_admin_role_name" {
  description = "Name of the cluster admin role for ArgoCD"
  type        = string
  default     = "argocd-cluster-admin"
}

variable "additional_rbac_rules" {
  description = "Additional RBAC rules for ArgoCD cluster manager"
  type = list(object({
    api_groups = list(string)
    resources  = list(string)
    verbs      = list(string)
  }))
  default = []
}

# Service Account Token Configuration
variable "service_account_token_expiration" {
  description = "Expiration time for service account tokens in seconds"
  type        = number
  default     = 86400 # 24 hours
}