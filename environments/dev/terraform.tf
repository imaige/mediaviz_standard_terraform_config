terraform {
  # required_version = "1.9.7"

  # where to store state files
  backend "s3" {
    bucket = "mediaviz-terraform-backend-config-dev"
    key    = "terraform.tfstate"
    region = "us-east-2" # since your EKS cluster is in us-east-2
  }

  # cloud providers
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # kubernetes, gpc, databricks, azure, etc
  }
}
