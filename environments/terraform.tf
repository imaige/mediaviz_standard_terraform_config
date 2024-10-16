terraform {
  required_version = "1.9.7"

  # where to store state files
  backend "s3" {
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