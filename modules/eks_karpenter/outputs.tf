# Outputs
output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "oidc_provider" {
  description = "OIDC Provider URL for the EKS cluster"
  value       = module.eks.oidc_provider
}

output "oidc_provider_arn" {
  description = "OIDC Provider ARN for the EKS cluster"
  value       = module.eks.oidc_provider_arn
}

output "node_security_group_id" {
  description = "Security group ID for the node groups"
  value       = module.eks.node_security_group_id
}

/*output "node_group_role_arn" {
  description = "IAM role ARN for the node groups"
  value       = module.eks.eks_managed_node_groups["primary"].iam_role_arn
}
*/
output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data # If using official eks module
  # Or if you need to access it differently based on your implementation:
  # value = aws_eks_cluster.this.certificate_authority[0].data
}
