# Data source to access the shared account's Terraform state
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "mediavizs-terraform-state"
    key    = "shared/terraform.tfstate"
    region = "us-east-2"
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}