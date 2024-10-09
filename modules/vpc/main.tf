// modules/vpc/main.tf
provider "aws" {
  region = "us-east-2" // Change to your desired region
}

variable "cluster_name" {
  description = "The cluster name"
  type        = string
}

variable "env" {
  description = "The environment name (e.g., dev, staging, prod)"
  type        = string
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 4.0"

  name = "${var.cluster_name}-${var.env}-vpc"
  cidr = "10.0.0.0/16"

  azs             = data.aws_availability_zones.available.names
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Terraform   = "true"
    Environment = var.cluster_name
  }
}

data "aws_availability_zones" "available" {}

# Output the VPC ID
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

# Output the Private Subnet IDs
output "private_subnets" {
  description = "The IDs of the private subnets"
  value       = module.vpc.private_subnets
}

# Output the Public Subnet IDs
output "public_subnets" {
  description = "The IDs of the public subnets"
  value       = module.vpc.public_subnets
}