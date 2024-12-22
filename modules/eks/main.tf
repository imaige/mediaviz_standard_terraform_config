module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = "${var.cluster_name}-${var.env}-cluster"
  cluster_version = var.cluster_version

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.control_plane_subnet_ids

  # Security configurations
  cluster_endpoint_public_access = true
  cluster_endpoint_private_access = true
  
  cluster_encryption_config = {
    provider_key_arn = var.kms_key_arn
    resources        = ["secrets"]
  }

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    primary_node_group = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.eks_primary_instance_type

      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_size

      # Enable detailed monitoring
      enable_monitoring = true

      # Enable EBS optimization
      ebs_optimized = true

      # Block device mappings
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 100
            volume_type          = "gp3"
            encrypted            = true
            kms_key_id          = var.kms_key_arn
            delete_on_termination = true
          }
        }
      }
    }
  }

  # Enable logging
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = {
    Environment = var.env
    Terraform   = "true"
  }
}

# Create CloudWatch log group for EKS logs
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/${var.cluster_name}-${var.env}-cluster"
  retention_in_days = 365  # Changed from 30 to 365
  kms_key_id       = var.kms_key_arn
}