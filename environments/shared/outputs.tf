# Outputs
output "account_id" {
  description = "The AWS account ID of the shared services account"
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "AWS region where resources are deployed"
  value       = data.aws_region.current.name
}

output "ecr_repository_urls" {
  description = "URLs of the created ECR repositories"
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "ARNs of the created ECR repositories"
  value       = module.ecr.repository_arns
}

output "s3_storage_bucket" {
  description = "Storage S3 bucket details"
  value = {
    name = module.s3_storage.bucket_id
    arn  = module.s3_storage.bucket_arn
  }
}

output "s3_artifacts_bucket" {
  description = "Artifacts S3 bucket details"
  value = {
    name = module.s3_artifacts.bucket_id
    arn  = module.s3_artifacts.bucket_arn
  }
}

output "s3_helm_charts_bucket" {
  description = "Helm charts S3 bucket details"
  value = {
    name = module.s3_helm_charts.bucket_id
    arn  = module.s3_helm_charts.bucket_arn
  }
}

output "cross_account_role_arn" {
  description = "ARN of the cross-account role for workload accounts"
  value       = module.cross_account_roles.role_arn
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions role"
  value       = module.github_oidc.role_arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  value       = module.security.kms_key_arn
}

output "kms_key_id" {
  description = "ID of the KMS key for encryption"
  value       = module.security.kms_key_id
}