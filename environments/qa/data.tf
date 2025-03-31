# Data source to access the shared account's Terraform state
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
  bucket         = "mediaviz-terraform-state-216989106985"
  key            = "shared/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "aws-controltower-terraform-state-lock"
  profile        = "shared-services"
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}

# Define locals for shared account resources
locals {
  shared_account_id = data.terraform_remote_state.shared.outputs.account_id
  
  # For troubleshooting - print available output attributes
  # This won't show in the plan, but it's useful to include
  # for_debug = tomap({for k, v in data.terraform_remote_state.shared.outputs : k => "${k}"})
  
  # Map shared account outputs to structured data
  shared_data = {
    # ECR repositories
    ecr_repository_urls = try(data.terraform_remote_state.shared.outputs.ecr_repository_urls, {})
    ecr_repository_arns = try(data.terraform_remote_state.shared.outputs.ecr_repository_arns, {})
    
    # S3 buckets - use direct references to available outputs
    s3_helm_charts_bucket = {
      # Adjust these based on your actual output structure
      arn = try(
        data.terraform_remote_state.shared.outputs.s3_buckets_storage_arn,
        data.terraform_remote_state.shared.outputs.s3_artifacts_bucket_arn,
        "arn:aws:s3:::${var.project_name}-shared-helm-charts"
      )
      id = try(
        data.terraform_remote_state.shared.outputs.s3_buckets_storage_id,
        data.terraform_remote_state.shared.outputs.s3_artifacts_bucket_id,
        "${var.project_name}-shared-helm-charts"
      )
    }
    
    # KMS keys
    kms_key_arn = data.terraform_remote_state.shared.outputs.kms_key_arn
    kms_key_id  = data.terraform_remote_state.shared.outputs.kms_key_id
    
    # IAM roles
    cross_account_role_arn = data.terraform_remote_state.shared.outputs.cross_account_role_arn
  }
  
  # Convert shared ECR repository ARNs to a list
  shared_ecr_repository_arns = [
    for repo in var.shared_ecr_repositories : 
    "arn:aws:ecr:${data.aws_region.current.name}:${local.shared_account_id}:repository/${var.project_name}-shared-${repo}"
  ]
  
  # Define a helper for S3 bucket ARNs to use in modules
  s3_helm_charts_bucket_arn = local.shared_data.s3_helm_charts_bucket.arn
}