output "account_id" {
  description = "The AWS account ID of the shared services account"
  value       = data.aws_caller_identity.current.account_id
}

output "ecr_repository_urls" {
  description = "The URLs of the ECR repositories"
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "The ARNs of the ECR repositories"
  value       = module.ecr.repository_arns
}

output "s3_buckets" {
  description = "Details of created S3 buckets"
  value = {
    storage = {
      bucket_id   = module.s3_storage.bucket_id
      bucket_arn  = module.s3_storage.bucket_arn
    }
    artifacts = {
      bucket_id   = module.s3_artifacts.bucket_id
      bucket_arn  = module.s3_artifacts.bucket_arn
    }
  }
}

output "cross_account_role_arn" {
  description = "ARN of the cross-account role that workload accounts can assume"
  value       = module.cross_account_roles.role_arn
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions role in the shared account"
  value       = module.github_oidc.role_arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for encryption"
  value       = module.security.kms_key_arn
}

output "kms_key_id" {
  description = "ID of the KMS key used for encryption"
  value       = module.security.kms_key_id
}