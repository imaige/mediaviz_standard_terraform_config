# environments/qa/outputs.tf

# Basic account information
output "account_id" {
  description = "The AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "AWS region where resources are deployed"
  value       = data.aws_region.current.name
}

# EKS Cluster outputs
output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for the EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_oidc_issuer" {
  description = "OIDC issuer URL for the EKS cluster"
  value       = module.eks.oidc_provider
}

# S3 bucket outputs
output "s3_bucket_id" {
  description = "ID of the S3 bucket for this environment"
  value       = module.s3.bucket_id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for this environment"
  value       = module.s3.bucket_arn
}

# Lambda outputs
output "lambda_upload_function_name" {
  description = "Name of the upload Lambda function"
  value       = module.lambda_upload.function_name
}

output "lambda_upload_function_arn" {
  description = "ARN of the upload Lambda function"
  value       = module.lambda_upload.function_arn
}

# Security outputs
output "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  value       = module.security.kms_key_arn
}

output "kms_key_id" {
  description = "ID of the KMS key for encryption"
  value       = module.security.kms_key_id
}

# Cross-account role ARN
output "cross_account_role_arn" {
  description = "ARN of the cross-account role to assume the shared account role"
  value       = module.cross_account_roles.role_arn
}

# GitHub Actions role ARN
output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions role"
  value       = module.github_oidc.role_arn
}

# Shared account resource references (via remote state)
output "shared_account_resources" {
  description = "Resources from the shared account"
  value = {
    account_id         = data.terraform_remote_state.shared.outputs.account_id
    ecr_repository_urls = data.terraform_remote_state.shared.outputs.ecr_repository_urls
    s3_storage_bucket  = data.terraform_remote_state.shared.outputs.s3_storage_bucket
    s3_artifacts_bucket = data.terraform_remote_state.shared.outputs.s3_artifacts_bucket
    kms_key_arn        = data.terraform_remote_state.shared.outputs.kms_key_arn
  }
}