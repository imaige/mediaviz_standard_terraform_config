terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "mediavizs-terraform-state"
    key            = "shared/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
    dynamodb_table = "mediaviz-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

#   default_tags {
#     tags = {
#       Environment = "shared"
#       Project     = var.project_name
#       Terraform   = "true"
#     }
#   }
}