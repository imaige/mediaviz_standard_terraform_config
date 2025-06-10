module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.cluster_name}-${var.env}-vpc"
  cidr = "192.168.0.0/16"

  azs             = data.aws_availability_zones.available.names
  public_subnets  = ["192.168.1.0/24", "192.168.2.0/24", "192.168.3.0/24"]
  private_subnets = ["192.168.16.0/22", "192.168.20.0/22", "192.168.24.0/22", "192.168.4.0/24", "192.168.5.0/24", "192.168.6.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Enable VPC flow logs
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_max_aggregation_interval    = 60

  # Enable Network ACLs
  manage_default_network_acl = true
  default_network_acl_tags = {
    Name = "${var.cluster_name}-${var.env}-default"
  }

  tags = {
    Terraform   = "true"
    Environment = var.env
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