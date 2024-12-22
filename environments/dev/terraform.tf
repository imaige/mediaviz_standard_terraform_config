terraform {
  # required_version = "1.9.7"

  # where to store state files
  backend "s3" {
    bucket         = "mediaviz-terraform-backend-config-dev"
    key            = "terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-state-lock"  # Add this line for state locking
    encrypt        = true
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
