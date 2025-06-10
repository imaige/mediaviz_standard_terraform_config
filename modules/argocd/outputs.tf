# ArgoCD module outputs

output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_server_url" {
  description = "ArgoCD server URL"
  value       = var.argocd_domain != "" ? "https://${var.argocd_domain}" : "http://argocd-server.${kubernetes_namespace.argocd.metadata[0].name}.svc.cluster.local"
}

output "argocd_server_service_account_arn" {
  description = "ARN of ArgoCD server service account IAM role"
  value       = aws_iam_role.argocd_server.arn
}

output "argocd_controller_service_account_arn" {
  description = "ARN of ArgoCD application controller service account IAM role"
  value       = aws_iam_role.argocd_controller.arn
}

output "argocd_server_service_account_name" {
  description = "Name of ArgoCD server service account"
  value       = kubernetes_service_account.argocd_server.metadata[0].name
}

output "argocd_controller_service_account_name" {
  description = "Name of ArgoCD application controller service account"
  value       = kubernetes_service_account.argocd_application_controller.metadata[0].name
}

output "github_repo_secret_name" {
  description = "Name of GitHub repository secret"
  value       = var.github_private_key != "" ? kubernetes_secret.github_repo_secret[0].metadata[0].name : ""
}

output "helm_release_name" {
  description = "Name of ArgoCD Helm release"
  value       = helm_release.argocd.name
}

output "helm_release_namespace" {
  description = "Namespace of ArgoCD Helm release"
  value       = helm_release.argocd.namespace
}

output "app_of_apps_enabled" {
  description = "Whether App of Apps pattern is enabled"
  value       = var.enable_app_of_apps
}

# Cluster connection information for external clusters
output "cluster_connection_info" {
  description = "Information for connecting ArgoCD to external clusters"
  value = {
    for name, config in var.external_cluster_configs : name => {
      server_url     = config.cluster_endpoint
      cluster_name   = config.cluster_name
      environment    = config.environment
      aws_account_id = config.aws_account_id
    }
  }
  sensitive = false
}

# ArgoCD admin credentials info
output "admin_credentials_info" {
  description = "Information about ArgoCD admin credentials"
  value = {
    username             = "admin"
    password_secret_name = "argocd-initial-admin-secret"
    password_secret_key  = "password"
    namespace           = kubernetes_namespace.argocd.metadata[0].name
  }
  sensitive = false
}