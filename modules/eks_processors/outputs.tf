# Outputs for reference in other modules
output "repository_urls" {
  description = "Map of ECR repository URLs"
  value = {
    for k, v in aws_ecr_repository.model_repos : k => v.repository_url
  }
}

output "repository_arns" {
  description = "Map of ECR repository ARNs"
  value = {
    for k, v in aws_ecr_repository.model_repos : k => v.arn
  }
}

output "role_arns" {
  description = "Map of IAM role ARNs for each model"
  value = {
    for k, v in aws_iam_role.model_role : k => v.arn
  }
}