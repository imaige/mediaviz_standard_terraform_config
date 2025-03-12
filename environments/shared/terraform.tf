terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

backend "s3" {
  bucket         = "mediaviz-terraform-state-216989106985"
  key            = "shared/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "aws-controltower-terraform-state-lock"
  profile        = "shared-services"
}
}

provider "aws" {
  region = var.aws_region
  profile = "shared-services"

#   default_tags {
#     tags = {
#       Environment = "shared"
#       Project     = var.project_name
#       Terraform   = "true"
#     }
#   }
}