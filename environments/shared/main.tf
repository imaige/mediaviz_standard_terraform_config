# Shared Services Account Configuration

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

import {
  to = module.s3_helm_charts.aws_s3_bucket.helm_charts
  id = "mediaviz-shared-helm-charts"
}

# Create KMS key for encryption
module "security" {
  source = "./../../modules/security"

  project_name = var.project_name
  env          = "shared"
  enable_sso   = false
  
  # Use a placeholder ARN or "*" for KMS until the real one exists
  kms_key_arn  = "*"
  kms_key_id   = ""
  cluster_name = "shared-placeholder"
  
  tags = var.tags
}

# Create ECR repositories
module "ecr" {
  source = "./../../modules/ecr"

  project_name = var.project_name
  env          = "shared"
  kms_key_arn  = module.security.kms_key_arn
  
  # Override the local repositories list in the module with our variable
  ecr_repositories = var.ecr_repositories
  
  # Cross-account access for workload accounts
  cross_account_arns = [
    for account_id in values(var.workload_account_ids) : 
    "arn:aws:iam::${account_id}:root"
  ]

  tags = var.tags
}

# Create S3 buckets
# Create S3 buckets
module "s3_storage" {
  source = "./../../modules/s3"

  project_name         = var.project_name
  env                  = "shared"
  bucket_suffix        = "storage"  # Add this to make bucket names unique
  cors_allowed_origins = var.s3_buckets["storage"].cors_allowed_origins
  retention_days       = var.s3_buckets["storage"].retention_days
  kms_key_arn          = module.security.kms_key_arn
  kms_key_id           = module.security.kms_key_id
  
  # Use variable for cross-account access instead of hardcoded ARN
  cross_account_arns = [
    for account_id in values(var.workload_account_ids) : 
    "arn:aws:iam::${account_id}:role/${var.project_name}-${var.workload_environments[index(values(var.workload_account_ids), account_id)]}-shared-account-access"
  ]
  
  tags = var.tags
}

module "s3_artifacts" {
  source = "./../../modules/s3"

  project_name         = var.project_name
  env                  = "shared"
  bucket_suffix        = "artifacts"  # Add this to make bucket names unique
  cors_allowed_origins = var.s3_buckets["artifacts"].cors_allowed_origins
  retention_days       = var.s3_buckets["artifacts"].retention_days
  kms_key_arn          = module.security.kms_key_arn
  kms_key_id           = module.security.kms_key_id
  
  # Use variable for cross-account access
  cross_account_arns = [
    for account_id in values(var.workload_account_ids) : 
    "arn:aws:iam::${account_id}:role/${var.project_name}-${var.workload_environments[index(values(var.workload_account_ids), account_id)]}-shared-account-access"
  ]
  
  tags = var.tags
}

# Create S3 bucket for Helm charts
module "s3_helm_charts" {
  source = "./../../modules/s3"

  project_name         = var.project_name
  env                  = "shared"
  bucket_suffix        = "helm"  # Add this to make bucket names unique
  helm_charts_bucket_name = "${var.project_name}-shared-helm-charts"  # Optional: explicit name
  cors_allowed_origins = ["*"]
  retention_days       = 365
  kms_key_arn          = module.security.kms_key_arn
  kms_key_id           = module.security.kms_key_id
  
  # Cross-account access for CI/CD
  cross_account_arns = [
    for account_id in values(var.workload_account_ids) : 
    "arn:aws:iam::${account_id}:role/${var.project_name}-${var.workload_environments[index(values(var.workload_account_ids), account_id)]}-shared-account-access"
  ]
  
  # CI/CD roles for write access
  ci_cd_role_arns = [
    module.github_oidc.role_arn
  ]
  
  tags = var.tags
}

# GitHub OIDC provider
module "github_oidc" {
  source         = "../../modules/github-oidc"
  project_name   = var.project_name
  env            = "shared"
  github_org     = var.github_org
  github_repo    = var.github_repo
  account_type   = "shared"
  aws_region     = data.aws_region.current.name
  aws_account_id = data.aws_caller_identity.current.account_id
  kms_key_arns   = [module.security.kms_key_arn]
  
  # Add shared S3 buckets for Helm charts
  shared_s3_arns = [
    module.s3_helm_charts.bucket_arn,
    "${module.s3_helm_charts.bucket_arn}/*"
  ]
  
  tags = var.tags
}

# Single cross-account role module for all workload accounts
module "cross_account_roles" {
  source = "../../modules/cross-account-roles"
  
  project_name = var.project_name
  account_type = "shared"
  env          = "shared"
  
  workload_account_arns = [
    for account_id in values(var.workload_account_ids) : 
    "arn:aws:iam::${account_id}:root"
  ]
  
  allowed_environments = keys(var.workload_account_ids)
  
  # All ECR repositories
  ecr_repository_arns = values(module.ecr.repository_arns)
  
  # All S3 buckets
  s3_bucket_arns = [
    module.s3_storage.bucket_arn,
    "${module.s3_storage.bucket_arn}/*",
    module.s3_artifacts.bucket_arn,
    "${module.s3_artifacts.bucket_arn}/*",
    module.s3_helm_charts.bucket_arn,
    "${module.s3_helm_charts.bucket_arn}/*"
  ]
  
  # KMS keys for encryption/decryption
  kms_key_arns = [
    module.security.kms_key_arn
  ]
  
  # CI/CD principals that need enhanced access
  cicd_principal_arns = [
    module.github_oidc.role_arn
  ]
  
  tags = var.tags
}