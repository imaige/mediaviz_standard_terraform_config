output "prometheus_workspace_id" {
  description = "ID of the Prometheus workspace"
  value       = aws_prometheus_workspace.main.id
}

output "prometheus_workspace_arn" {
  description = "ARN of the Prometheus workspace"
  value       = aws_prometheus_workspace.main.arn
}

output "prometheus_workspace_endpoint" {
  description = "Prometheus workspace endpoint for remote write"
  value       = aws_prometheus_workspace.main.prometheus_endpoint
}

output "prometheus_workspace_alias" {
  description = "Prometheus workspace alias"
  value       = aws_prometheus_workspace.main.alias
}

output "grafana_workspace_id" {
  description = "ID of the Grafana workspace"
  value       = aws_grafana_workspace.main.id
}

output "grafana_workspace_arn" {
  description = "ARN of the Grafana workspace"
  value       = aws_grafana_workspace.main.arn
}

output "grafana_workspace_endpoint" {
  description = "Grafana workspace endpoint URL"
  value       = aws_grafana_workspace.main.endpoint
}

output "grafana_workspace_grafana_version" {
  description = "Grafana version"
  value       = aws_grafana_workspace.main.grafana_version
}

output "grafana_role_arn" {
  description = "ARN of the IAM role for Grafana"
  value       = aws_iam_role.grafana_role.arn
}

output "prometheus_scraping_role_arn" {
  description = "ARN of the IAM role for Prometheus scraping (if enabled)"
  value       = var.enable_eks_integration ? aws_iam_role.prometheus_scraping_role[0].arn : null
}

output "prometheus_log_group_name" {
  description = "Name of the CloudWatch log group for Prometheus"
  value       = aws_cloudwatch_log_group.prometheus_logs.name
}

output "prometheus_log_group_arn" {
  description = "ARN of the CloudWatch log group for Prometheus"
  value       = aws_cloudwatch_log_group.prometheus_logs.arn
}

output "grafana_api_key" {
  description = "Grafana API key for Prometheus data source (if created)"
  value       = var.create_prometheus_datasource ? aws_grafana_workspace_api_key.prometheus_access[0].key : null
  sensitive   = true
}

output "security_group_id" {
  description = "ID of the security group for Grafana (if created)"
  value       = var.vpc_id != "" ? aws_security_group.grafana[0].id : null
}

output "prometheus_namespace" {
  description = "Name of the Kubernetes namespace for monitoring"
  value       = var.enable_eks_integration && var.deploy_prometheus_to_eks ? kubernetes_namespace.monitoring[0].metadata[0].name : null
}

output "prometheus_service_account_name" {
  description = "Name of the Kubernetes service account for Prometheus"
  value       = var.enable_eks_integration && var.deploy_prometheus_to_eks ? kubernetes_service_account.prometheus[0].metadata[0].name : null
}

output "prometheus_helm_status" {
  description = "Status of the Prometheus Helm release"
  value       = var.enable_eks_integration && var.deploy_prometheus_to_eks ? helm_release.prometheus[0].status : null
}