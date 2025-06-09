# Outputs for ArgoCD cluster configuration module

output "argocd_service_account_name" {
  description = "Name of the ArgoCD service account"
  value       = var.create_argocd_service_account ? kubernetes_service_account.argocd_manager[0].metadata[0].name : ""
}

output "argocd_service_account_arn" {
  description = "ARN of the ArgoCD service account IAM role"
  value       = var.create_argocd_service_account ? aws_iam_role.argocd_cluster_manager[0].arn : ""
}

output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = var.argocd_namespace
}

output "cluster_role_name" {
  description = "Name of the ArgoCD cluster role"
  value       = var.create_argocd_service_account ? kubernetes_cluster_role.argocd_manager[0].metadata[0].name : ""
}

output "cluster_role_binding_name" {
  description = "Name of the ArgoCD cluster role binding"
  value       = var.create_argocd_service_account ? kubernetes_cluster_role_binding.argocd_manager[0].metadata[0].name : ""
}

output "cluster_config_secret_name" {
  description = "Name of the cluster configuration secret"
  value       = var.create_cluster_secret ? kubernetes_secret.cluster_config[0].metadata[0].name : ""
}

# Information needed for ArgoCD cluster registration
output "cluster_connection_info" {
  description = "Information for registering this cluster with ArgoCD"
  value = {
    name                    = var.cluster_name
    server                  = var.cluster_endpoint
    service_account_name    = var.create_argocd_service_account ? kubernetes_service_account.argocd_manager[0].metadata[0].name : ""
    service_account_token   = var.create_argocd_service_account ? kubernetes_service_account.argocd_manager[0].metadata[0].name : ""
    namespace              = var.argocd_namespace
    cross_account_role_arn = var.cross_account_role_arn
    environment            = var.env
  }
  sensitive = false
}

# Service account token for external ArgoCD
output "service_account_token_secret" {
  description = "Service account token secret information"
  value = var.create_argocd_service_account ? {
    secret_name = kubernetes_service_account.argocd_manager[0].default_secret_name
    namespace   = var.argocd_namespace
  } : null
  sensitive = true
}