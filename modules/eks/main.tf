module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.cluster_name}-${var.env}-cluster"
  cluster_version = var.cluster_version

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.control_plane_subnet_ids

  cluster_endpoint_public_access = true

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy            = {}
    vpc-cni               = {}
  }

  eks_managed_node_groups = {
    primary_node_group = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.eks_primary_instance_type

      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_size
    }
  }

  tags = {
    Environment = var.env
    Terraform   = "true"
  }
}