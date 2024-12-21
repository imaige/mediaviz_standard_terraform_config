module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 4.0"

  name = "${var.cluster_name}-${var.env}-vpc"
  cidr = "192.168.0.0/16"

  azs             = data.aws_availability_zones.available.names
  public_subnets  = ["192.168.1.0/24", "192.168.2.0/24", "192.168.3.0/24"]
  private_subnets = ["192.168.4.0/24", "192.168.5.0/24", "192.168.6.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true  # note: may want to swap to False when creating prod cluster

  tags = {
    Terraform   = "true"
    Environment = var.env  # Changed from cluster_name to env
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    "Environment"            = var.env
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "Environment"                     = var.env
  }
}

data "aws_availability_zones" "available" {}