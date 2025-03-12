# Shared Services Account Configuration

# Data sources
data "aws_caller_identity" "current" {}

# Create KMS key for encryption
# shared/main.tf
module "security" {
  source = "./../../modules/security"

  project_name = var.project_name
  env          = "shared"
  enable_sso   = false
  
  # Use a placeholder ARN or "*" for KMS until the real one exists
  kms_key_arn  = "*"  # This will allow access to any KMS key for now
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
  
  # Empty list for now, will be populated with workload account ARNs
  cross_account_arns = [
    for account_id in values(var.workload_account_ids) : 
    "arn:aws:iam::${account_id}:root"
  ]

  tags = var.tags
}

# Create S3 buckets
module "s3_storage" {
  source = "./../../modules/s3"

  project_name         = var.project_name
  env                  = "shared"
  cors_allowed_origins = var.s3_buckets["storage"].cors_allowed_origins
  retention_days       = var.s3_buckets["storage"].retention_days
  kms_key_arn          = module.security.kms_key_arn
  kms_key_id           = module.security.kms_key_id
  replica_kms_key_id   = module.security.kms_key_id  # Required parameter
}

module "s3_artifacts" {
  source = "./../../modules/s3"

  project_name         = var.project_name
  env                  = "shared"
  cors_allowed_origins = var.s3_buckets["artifacts"].cors_allowed_origins
  retention_days       = var.s3_buckets["artifacts"].retention_days
  kms_key_arn          = module.security.kms_key_arn
  kms_key_id           = module.security.kms_key_id
  replica_kms_key_id   = module.security.kms_key_id  # Required parameter
}

# GitHub OIDC provider
module "github_oidc" {
  source = "./../../modules/github-oidc"
  
  project_name = var.project_name
  env          = "shared"
  github_org   = var.github_org
  github_repo  = var.github_repo
  account_type = "shared"
  
  tags = var.tags
}

# Cross-account roles for workload accounts
module "cross_account_roles" {
  source = "./../../modules/cross-account-roles"
  
  project_name = var.project_name
  account_type = "shared"
  
  workload_account_arns = [
    for account_id in values(var.workload_account_ids) : 
    "arn:aws:iam::${account_id}:root"
  ]
  
  allowed_environments = keys(var.workload_account_ids)
  
  ecr_repository_arns = values(module.ecr.repository_arns)
  
  s3_bucket_arns = [
    module.s3_storage.bucket_arn,
    module.s3_artifacts.bucket_arn
  ]
  
  tags = var.tags
}