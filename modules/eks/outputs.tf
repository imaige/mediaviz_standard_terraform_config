# eks/outputs.tf

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = module.eks.cluster_arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "cluster_platform_version" {
  description = "Platform version for the cluster"
  value       = module.eks.cluster_platform_version
}

output "cluster_status" {
  description = "Status of the EKS cluster. One of `CREATING`, `ACTIVE`, `DELETING`, `FAILED`"
  value       = module.eks.cluster_status
}

output "cluster_security_group_id" {
  description = "Cluster security group that was created by Amazon EKS for the cluster"
  value       = module.eks.cluster_security_group_id
}

# This is what we need for SQS access
output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = module.eks.node_security_group_id
}

# IAM Role for node groups
output "eks_managed_node_groups_iam_role_arns" {
  description = "IAM role ARNs of EKS managed node groups"
  value       = module.eks.eks_managed_node_groups_iam_role_arns
}

# Main node IAM role ARN to use for SQS
output "node_group_role_arn" {
  description = "IAM role ARN for EKS managed node group"
  value       = module.eks.eks_managed_node_groups["primary_node_group"].iam_role_arn
}

# OIDC Provider
output "oidc_provider" {
  description = "The OpenID Connect identity provider (issuer URL without leading `https://`)"
  value       = module.eks.oidc_provider
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider"
  value       = module.eks.oidc_provider_arn
}

# CloudWatch Log Group
output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for the EKS cluster"
  value       = aws_cloudwatch_log_group.api_logs.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for the EKS cluster"
  value       = aws_cloudwatch_log_group.api_logs.arn
}