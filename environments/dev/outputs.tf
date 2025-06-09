output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role"
  value       = module.github_oidc.role_arn
}

output "eks_admin_role_arn" {
  description = "ARN of the EKS admin role"
  value       = module.security.eks_admin_role_arn
}