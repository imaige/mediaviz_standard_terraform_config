# environments/qa/terraform.tf

terraform {
  backend "s3" {
    bucket         = "mediaviz-tf-backend-qa-2025"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "mediaviz-terraform-backend-config-qa"
    encrypt        = true
    profile        = "mediaviz-qa"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

# Provider for the current account
provider "aws" {
  region  = "us-east-2" # Make sure this matches the region where your cluster exists
  profile = "mediaviz-qa"

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.env
      Terraform   = "true"
      ManagedBy   = "terraform"
    }
  }
}

# Provider for the shared account
provider "aws" {
  alias   = "shared"
  region  = var.aws_region
  profile = "shared-services"
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
    }
  }
}