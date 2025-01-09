terraform {
  # required_version = "1.9.7"

  # where to store state files
  backend "s3" {
    bucket         = "mediaviz-terraform-backend-config-dev"
    key            = "terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "mediaviz-terraform-backend-config-dev"
    encrypt        = true
  }

  # cloud providers
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

# Provider configurations
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.env
      Terraform   = "true"
      ManagedBy   = "terraform"
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", "${var.cluster_name}-${var.env}-cluster"]
  }
}

provider "time" {}