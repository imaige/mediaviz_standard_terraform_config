# modules/eks_processors/outputs.tf

output "repository_urls" {
 description = "URLs of the created ECR repositories"
 value = {
   for k, v in aws_ecr_repository.model_repos : k => v.repository_url
 }
}

output "repository_arns" {
 description = "ARNs of the created ECR repositories"
 value = {
   for k, v in aws_ecr_repository.model_repos : k => v.arn
 }
}

output "role_arns" {
 description = "ARNs of the IAM roles created for each model"
 value = {
   for k, v in aws_iam_role.model_role : k => v.arn
 }
}

output "model_names" {
 description = "Names of the deployed models"
 value       = keys(local.models)
}