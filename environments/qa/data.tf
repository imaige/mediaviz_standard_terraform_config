# environments/qa/data.tf

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

# AWS region for the current deployment
data "aws_region" "current_region" {
  provider = aws
}

# Optional: Get more information about the EKS cluster
data "aws_eks_cluster" "this" {
  name = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
  depends_on = [module.eks]
}